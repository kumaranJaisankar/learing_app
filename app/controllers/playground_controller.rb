# frozen_string_literal: true

class PlaygroundController < ApplicationController
  # Skip CSRF token for the local developer playground simulation
  skip_before_action :verify_authenticity_token, only: [:generate_packet, :submit_packet, :reset_ledger]

  def index
    @products = Product.all.order(:id)
    @agents = AgentIdentity.all.order(:id)
    @ledgers = TrustPacketLedger.recent.limit(15)
    @recent_orders = Order.includes(:product, :agent_identity).order(created_at: :desc).limit(10)

    # Initial default packet for immediate hands-on play
    default_agent = @agents.find_by(active: true) || @agents.first
    default_product = @products.first

    if default_agent && default_product
      client = UnikeyService::ClientAgent.for_agent(default_agent)
      @initial_packet_json = JSON.pretty_generate(
        client.build_purchase_packet(sku: default_product.sku, quantity: 2, max_budget: 100.0).to_h
      )
    else
      @initial_packet_json = "{}"
    end
  end

  def generate_packet
    agent = AgentIdentity.find_by(domain: params[:agent_domain])
    product = Product.find_by(sku: params[:sku]) || Product.first
    quantity = (params[:quantity] || 1).to_i
    scenario = params[:scenario] || "legitimate"

    unless agent && product
      return render json: { error: "Agent or Product not found" }, status: :unprocessable_entity
    end

    client = UnikeyService::ClientAgent.for_agent(agent)

    packet_hash = case scenario
                  when "legitimate"
                    client.build_purchase_packet(
                      sku: product.sku,
                      quantity: quantity,
                      max_budget: [agent.authorized_budget, 100.0].max
                    ).to_h
                  when "tampered"
                    client.build_tampered_packet(
                      sku: product.sku,
                      quantity: quantity,
                      forged_quantity: quantity + 50,
                      max_budget: 1000.0
                    )
                  when "expired"
                    client.build_expired_packet(sku: product.sku, quantity: quantity)
                  when "overbudget"
                    # Authorize low budget (e.g. $1.00) while ordering an expensive product
                    client.build_purchase_packet(
                      sku: product.sku,
                      quantity: quantity,
                      max_budget: 1.00
                    ).to_h
                  when "forged_key"
                    client.build_forged_key_packet(sku: product.sku, quantity: quantity)
                  else
                    client.build_purchase_packet(sku: product.sku, quantity: quantity).to_h
                  end

    render json: {
      scenario: scenario,
      packet_id: packet_hash.dig(:header, :packet_id) || packet_hash.dig("header", "packet_id"),
      packet_json: JSON.pretty_generate(packet_hash)
    }
  end

  def submit_packet
    raw_packet = params[:packet_json]

    result = UnikeyService::OrderProcessor.process(raw_packet)

    render json: {
      success: result.success,
      error_code: result.error_code,
      error_message: result.error_message,
      packet_id: result.packet_id,
      signer: result.signer,
      subject: result.subject,
      product: result.product ? { name: result.product.name, sku: result.product.sku, price: result.product.price } : nil,
      quantity: result.quantity,
      total_amount: result.total_amount,
      order_id: result.order&.id,
      response_packet_json: result.response_packet ? JSON.pretty_generate(result.response_packet) : nil,
      steps: result.steps
    }
  end

  def reset_ledger
    Order.destroy_all
    TrustPacketLedger.destroy_all
    redirect_to root_path, notice: "Authorization Ledger and Orders reset successfully."
  end
end
