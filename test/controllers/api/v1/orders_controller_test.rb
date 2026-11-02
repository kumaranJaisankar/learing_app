# frozen_string_literal: true

require "test_helper"

class Api::V1::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent = AgentIdentity.find_by!(domain: "procure.ai")
    @client = UnikeyService::ClientAgent.for_agent(@agent)
    @product = Product.find_by!(sku: "COMPUTE-H100-1H")
  end

  test "GET /api/v1/products returns product catalog" do
    get api_v1_products_url, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |p| p["sku"] == @product.sku }
  end

  test "POST /api/v1/orders creates order with valid trust packet" do
    packet = @client.build_purchase_packet(sku: @product.sku, quantity: 1, max_budget: 100.0)

    post api_v1_orders_url, params: packet.to_h, as: :json
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "fulfilled", json["status"]
    assert_not_nil json["order_id"]
    assert_not_nil json["response_packet"]
  end

  test "POST /api/v1/orders rejects tampered packet" do
    tampered = @client.build_tampered_packet(sku: @product.sku, quantity: 1, forged_quantity: 99)

    post api_v1_orders_url, params: tampered, as: :json
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_equal "invalid_signature", json["error_code"]
  end

  test "POST /api/v1/verify returns validation status" do
    packet = @client.build_purchase_packet(sku: @product.sku, quantity: 1)

    post api_v1_verify_url, params: packet.to_h, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["valid"]
    assert_equal "procure.ai", json["signer"]
  end
end
