# frozen_string_literal: true

module Api
  module V1
    class OrdersController < ActionController::API
      def index
        orders = Order.includes(:product, :agent_identity, :trust_packet_ledger).order(created_at: :desc).limit(50)
        render json: orders.as_json(
          include: {
            product: { only: [:id, :name, :sku, :price] },
            agent_identity: { only: [:domain, :selector] },
            trust_packet_ledger: { only: [:packet_id, :status, :signer_domain, :created_at] }
          }
        )
      end

      def show
        order = Order.find(params[:id])
        render json: order.as_json(
          include: {
            product: { only: [:id, :name, :sku, :price] },
            agent_identity: { only: [:domain] },
            trust_packet_ledger: { only: [:packet_id, :status, :signer_domain, :created_at] }
          }
        ).merge("response_packet" => order.parsed_response_packet)
      end

      # POST /api/v1/orders
      # Accepts a raw Trust Packet JSON body or parses headers
      def create
        packet_payload = extract_packet_payload

        unless packet_payload
          return render json: {
            error: "bad_request",
            message: "Missing Trust Packet. Provide packet JSON in request body."
          }, status: :bad_request
        end

        result = UnikeyService::OrderProcessor.process(packet_payload)

        if result.success
          render json: {
            success: true,
            status: "fulfilled",
            order_id: result.order.id,
            product: result.product.name,
            sku: result.product.sku,
            quantity: result.quantity,
            total_amount: result.total_amount,
            packet_id: result.packet_id,
            signer: result.signer,
            subject: result.subject,
            response_packet: result.response_packet,
            verification_steps: result.steps
          }, status: :created
        else
          http_status = case result.error_code
                        when :invalid_signature, :expired_packet, :replay_attack, :identity_revoked
                          :unauthorized
                        when :budget_exceeded, :out_of_stock
                          :unprocessable_entity
                        else
                          :bad_request
                        end

          render json: {
            success: false,
            error_code: result.error_code,
            message: result.error_message,
            packet_id: result.packet_id,
            signer: result.signer,
            verification_steps: result.steps
          }, status: http_status
        end
      end

      # POST /api/v1/verify
      # Verifies a packet like UniKey Cloud without executing an order
      def verify_only
        packet_payload = extract_packet_payload

        unless packet_payload
          return render json: { valid: false, error: "Missing packet payload" }, status: :bad_request
        end

        # Temporary validation without persisting order
        packet_data = packet_payload.is_a?(Hash) ? packet_payload : JSON.parse(packet_payload)
        verified = UniKey::TrustPacket.verify(packet_data)

        if verified
          render json: {
            valid: true,
            packet_id: verified.packet_id,
            subject: verified.subject,
            action: verified.action,
            signer: verified.signer,
            scope: verified.scope,
            verified_at: Time.now.utc.iso8601
          }
        else
          render json: {
            valid: false,
            error: "Verification failed (signature mismatch, expired, or invalid format)"
          }, status: :unauthorized
        end
      end

      private

      def extract_packet_payload
        raw_body = request.body.read
        return raw_body if raw_body.present?

        params[:trust_packet] || params[:packet] || (params.key?("header") ? params.to_unsafe_h : nil)
      end
    end
  end
end
