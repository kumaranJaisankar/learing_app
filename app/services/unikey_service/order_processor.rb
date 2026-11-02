# frozen_string_literal: true

require "digest"

module UnikeyService
  class OrderProcessor
    Result = Struct.new(
      :success,
      :error_code,
      :error_message,
      :packet_id,
      :signer,
      :subject,
      :product,
      :quantity,
      :total_amount,
      :order,
      :ledger,
      :response_packet,
      :steps,
      keyword_init: true
    )

    def self.process(raw_input)
      new(raw_input).process
    end

    def initialize(raw_input)
      @raw_string = raw_input.is_a?(String) ? raw_input : raw_input.to_json
      parsed = raw_input.is_a?(Hash) ? raw_input : (JSON.parse(raw_input) rescue nil)
      @data = parsed.is_a?(Hash) ? parsed.deep_stringify_keys : nil
      @steps = []
    end

    def process
      ServerKey.ensure_registered!

      # 1. Structure Verification
      unless @data.is_a?(Hash) && @data["header"] && @data["claims"] && @data["payload"] && @data["signatures"]
        add_step("Structure Validation", false, "Packet is missing required top-level keys (header, claims, payload, signatures)")
        return fail_result(:invalid_format, "Malformed Trust Packet JSON")
      end
      add_step("Structure Validation", true, "All required RFC-001 sections are present (version #{@data.dig('header', 'tp_version')})")

      packet_id = @data.dig("header", "packet_id").to_s
      signer_domain = @data.dig("signatures", 0, "signer").to_s
      subject = @data.dig("claims", "subject").to_s
      action = @data.dig("payload", "action").to_s

      # 2. Replay Protection (Anti-Replay Nonce Check)
      existing_ledger = TrustPacketLedger.find_by(packet_id: packet_id)
      if existing_ledger
        add_step("Replay Protection", false, "Packet ID #{packet_id} was already seen at #{existing_ledger.created_at.iso8601}. Replay blocked!")
        @ledger = existing_ledger
        return fail_result(:replay_attack, "Replay attack detected: Packet ID has already been processed", packet_id: packet_id)
      end
      add_step("Replay Protection", true, "Unique Packet ID #{packet_id} confirmed against authorization ledger")

      # 3. Expiration / Timestamp Check
      expires_at_str = @data.dig("header", "expires_at")
      expires_at = Time.parse(expires_at_str.to_s) rescue nil
      if expires_at && Time.now.utc > expires_at
        add_step("TTL & Expiration", false, "Packet expired at #{expires_at.iso8601} (Current time: #{Time.now.utc.iso8601})")
        record_ledger!(status: "rejected", failure_reason: "Expired Trust Packet")
        return fail_result(:expired_packet, "Trust Packet expired before arrival", packet_id: packet_id)
      end
      add_step("TTL & Expiration", true, "Valid packet timestamp: expires in #{(expires_at - Time.now.utc).round(1)}s")

      # 4. DNS Public Key Discovery
      public_key_b64 = nil
      begin
        public_key_b64 = UniKey::DNS.lookup(signer_domain)
        add_step("DNS Key Discovery", true, "Resolved Ed25519 public key for '#{signer_domain}' from unikey._domainkey.#{signer_domain}")
      rescue => e
        add_step("DNS Key Discovery", false, "Could not resolve DNS key for #{signer_domain}: #{e.message}")
        record_ledger!(status: "rejected", failure_reason: "DNS Key Lookup Failed: #{e.message}")
        return fail_result(:dns_lookup_failed, "DNS discovery failed for signer: #{signer_domain}", packet_id: packet_id)
      end

      # 5. Cryptographic Ed25519 Signature Verification
      begin
        # Use UniKey::TrustPacket verification
        verified_claims = UniKey::TrustPacket.verify!(@data)
        add_step("Cryptographic Signature", true, "Ed25519 signature verified successfully over canonicalized packet digest")
      rescue UniKey::InvalidSignature => e
        add_step("Cryptographic Signature", false, "Signature mismatch! Payload was tampered or signed with wrong key")
        record_ledger!(status: "rejected", failure_reason: "Invalid cryptographic signature")
        return fail_result(:invalid_signature, "Ed25519 signature verification failed (tampered data)", packet_id: packet_id)
      rescue => e
        add_step("Cryptographic Signature", false, "Cryptographic verification error: #{e.message}")
        record_ledger!(status: "rejected", failure_reason: "Crypto Error: #{e.message}")
        return fail_result(:crypto_error, e.message, packet_id: packet_id)
      end

      # 6. Identity Revocation Check
      agent = AgentIdentity.find_by(domain: signer_domain)
      if agent && !agent.active?
        add_step("Agent Identity Status", false, "Signer domain '#{signer_domain}' is revoked or deactivated")
        record_ledger!(status: "rejected", failure_reason: "Signer identity revoked")
        return fail_result(:identity_revoked, "Agent identity has been revoked", packet_id: packet_id)
      end
      add_step("Agent Identity Status", true, "Signer domain '#{signer_domain}' is active and authorized")

      # 7. Action Verification
      unless action == "purchase_item"
        add_step("Action Verification", false, "Action '#{action}' is not supported by checkout service")
        record_ledger!(status: "rejected", failure_reason: "Unsupported action: #{action}")
        return fail_result(:unsupported_action, "Unsupported action: #{action}", packet_id: packet_id)
      end
      add_step("Action Verification", true, "Action 'purchase_item' recognized")

      # 8. Product & Price Validation
      params = @data.dig("payload", "params") || {}
      sku = params["sku"] || params[:sku]
      product_id = params["product_id"] || params[:product_id]
      quantity = (params["quantity"] || params[:quantity] || 1).to_i

      product = if sku.present?
                  Product.find_by(sku: sku)
                elsif product_id.present?
                  Product.find_by(id: product_id)
                end

      unless product
        add_step("Product Inventory", false, "Product not found for SKU: #{sku.inspect} or ID: #{product_id.inspect}")
        record_ledger!(status: "rejected", failure_reason: "Product not found")
        return fail_result(:product_not_found, "Requested product is not available", packet_id: packet_id)
      end

      if product.stock < quantity
        add_step("Product Inventory", false, "Insufficient inventory. Requested #{quantity}, available #{product.stock}")
        record_ledger!(status: "rejected", failure_reason: "Insufficient inventory")
        return fail_result(:out_of_stock, "Insufficient product stock", packet_id: packet_id)
      end

      total_cost = (product.price * quantity).round(2)
      add_step("Product Inventory", true, "Found product '#{product.name}' ($#{product.price} x #{quantity} = $#{total_cost})")

      # 9. Scope & Spending Limit Policy Check
      scope = Array(@data.dig("claims", "scope"))
      scope_budget = extract_scope_budget(scope)
      agent_budget = agent ? agent.authorized_budget : Float::INFINITY

      effective_budget = [scope_budget, agent_budget].compact.min

      if total_cost > effective_budget
        add_step("Authorization Scope & Budget", false, "Order total ($#{total_cost}) exceeds authorized budget cap ($#{effective_budget})")
        record_ledger!(status: "rejected", failure_reason: "Budget limit exceeded ($#{total_cost} > $#{effective_budget})")
        return fail_result(:budget_exceeded, "Order total exceeds authorized limit ($#{total_cost} > $#{effective_budget})", packet_id: packet_id)
      end
      add_step("Authorization Scope & Budget", true, "Authorized within budget cap ($#{total_cost} <= $#{effective_budget})")

      # 10. Ledger Settlement & Order Execution
      ledger = record_ledger!(status: "verified", failure_reason: nil)
      product.decrement!(:stock, quantity)

      # Build Signed Response Trust Packet back to agent
      response_packet = build_response_packet(
        request_packet_id: packet_id,
        subject: subject,
        product: product,
        quantity: quantity,
        total: total_cost
      )

      order = Order.create!(
        product: product,
        agent_identity: agent,
        trust_packet_ledger: ledger,
        quantity: quantity,
        unit_price: product.price,
        total_amount: total_cost,
        status: "fulfilled",
        response_packet: response_packet.to_json
      )

      add_step("Order Settlement & Response", true, "Order ##{order.id} executed. Response Trust Packet generated and signed by #{ServerKey::DOMAIN}")

      Result.new(
        success: true,
        error_code: nil,
        error_message: nil,
        packet_id: packet_id,
        signer: signer_domain,
        subject: subject,
        product: product,
        quantity: quantity,
        total_amount: total_cost,
        order: order,
        ledger: ledger,
        response_packet: response_packet.to_h.deep_stringify_keys,
        steps: @steps
      )
    end

    private

    def add_step(name, passed, detail)
      @steps << { name: name, passed: passed, detail: detail, timestamp: Time.now.utc.iso8601 }
    end

    def fail_result(code, message, packet_id: nil)
      Result.new(
        success: false,
        error_code: code,
        error_message: message,
        packet_id: packet_id || @data&.dig("header", "packet_id"),
        signer: @data&.dig("signatures", 0, "signer"),
        subject: @data&.dig("claims", "subject"),
        product: nil,
        quantity: 0,
        total_amount: 0,
        order: nil,
        ledger: @ledger,
        response_packet: nil,
        steps: @steps
      )
    end

    def record_ledger!(status:, failure_reason:)
      packet_id = @data&.dig("header", "packet_id") || SecureRandom.uuid
      signer = @data&.dig("signatures", 0, "signer") || "unknown"
      subject = @data&.dig("claims", "subject") || "unknown"
      action = @data&.dig("payload", "action") || "unknown"

      digest = Digest::SHA256.hexdigest(@raw_string)

      @ledger = TrustPacketLedger.create!(
        packet_id: packet_id,
        signer_domain: signer,
        subject: subject,
        action: action,
        status: status,
        failure_reason: failure_reason,
        payload_digest: digest,
        raw_packet: @raw_string,
        verified_at: status == "verified" ? Time.now.utc : nil
      )
    end

    def extract_scope_budget(scopes)
      scopes.each do |s|
        if s =~ /^(?:spend|max_budget|budget):(\d+(?:\.\d+)?)$/
          return $1.to_f
        end
      end
      nil
    end

    def build_response_packet(request_packet_id:, subject:, product:, quantity:, total:)
      UniKey.build_packet(
        subject: "orders@#{ServerKey::DOMAIN}",
        audience: subject,
        action: "purchase_item_response",
        packet_type: "action_response",
        scope: ["order:confirmation"],
        params: {
          request_packet_id: request_packet_id,
          order_status: "confirmed",
          product_name: product.name,
          sku: product.sku,
          quantity: quantity,
          total_charged: total,
          currency: "USD",
          fulfillment_timestamp: Time.now.utc.iso8601
        },
        message: "Your purchase of #{quantity}x #{product.name} was successfully authorized and fulfilled.",
        signing_key: ServerKey.signing_key,
        signer_domain: ServerKey::DOMAIN,
        ttl: 3600
      )
    end
  end
end
