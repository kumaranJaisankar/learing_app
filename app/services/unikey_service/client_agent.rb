# frozen_string_literal: true

require "ed25519"
require "base64"

module UnikeyService
  class ClientAgent
    attr_reader :domain, :subject, :signing_key, :public_key_b64

    def self.for_agent(agent_identity)
      priv_bytes = Base64.strict_decode64(agent_identity.simulated_private_key)
      key = Ed25519::SigningKey.new(priv_bytes)
      new(domain: agent_identity.domain, signing_key: key)
    end

    def initialize(domain:, signing_key: nil)
      @domain = domain
      @signing_key = signing_key || Ed25519::SigningKey.generate
      @public_key_b64 = Base64.strict_encode64(@signing_key.verify_key.to_bytes)
      @subject = "agent@#{@domain}"
    end

    # Builds a standard legitimate Trust Packet
    def build_purchase_packet(sku:, quantity: 1, max_budget: 100.0, ttl: 300, message: "Autonomous procurement request")
      UniKey.build_packet(
        subject: @subject,
        audience: "orders@cloudstore.local",
        action: "purchase_item",
        scope: ["purchase:#{sku}", "spend:#{max_budget}"],
        params: {
          sku: sku,
          quantity: quantity,
          callback_url: "https://#{@domain}/api/callbacks/orders"
        },
        message: message,
        signing_key: @signing_key,
        signer_domain: @domain,
        ttl: ttl
      )
    end

    # Builds a packet and then intentionally tampers with the payload after signing
    def build_tampered_packet(sku:, quantity: 1, forged_quantity: 99, max_budget: 100.0)
      legit = build_purchase_packet(sku: sku, quantity: quantity, max_budget: max_budget)
      hash = legit.to_h

      # Maliciously mutate params after cryptographic signature was created
      hash[:payload][:params][:quantity] = forged_quantity
      hash[:payload][:message] = "TAMPERED: Changed quantity to #{forged_quantity}"
      hash
    end

    # Builds an expired packet (expires_at set 10 minutes in the past)
    def build_expired_packet(sku:, quantity: 1)
      packet = build_purchase_packet(sku: sku, quantity: quantity, ttl: -600)
      # Re-sign with expired header
      packet.to_h
    end

    # Builds a packet signed by an unknown / untrusted key not in DNS
    def build_forged_key_packet(sku:, quantity: 1)
      attacker_key = Ed25519::SigningKey.generate
      UniKey.build_packet(
        subject: "attacker@#{@domain}",
        audience: "orders@cloudstore.local",
        action: "purchase_item",
        scope: ["purchase:#{sku}", "spend:500.0"],
        params: { sku: sku, quantity: quantity },
        message: "Attempt with forged key not published in DNS",
        signing_key: attacker_key,
        signer_domain: @domain
      ).to_h
    end
  end
end
