# frozen_string_literal: true

require_relative "../config/environment"

def assert(condition, message = "Assertion failed")
  raise "ASSERTION FAILED: #{message}" unless condition
  puts "  ✓ #{message}"
end

puts "\n========================================================"
puts "  UniKey Universal Trust Protocol Self-Check Test Suite"
puts "========================================================\n"

# Setup
agent = AgentIdentity.find_by!(domain: "procure.ai")
client = UnikeyService::ClientAgent.for_agent(agent)
product = Product.find_by!(sku: "COMPUTE-H100-1H")
initial_stock = product.stock

# Test 1: Legitimate Purchase Request
puts "[Test 1] Legitimate Agent Purchase"
legit_packet = client.build_purchase_packet(sku: product.sku, quantity: 2, max_budget: 100.0)
res = UnikeyService::OrderProcessor.process(legit_packet.to_h)

unless res.success
  puts "FAILED! Error: #{res.error_code} - #{res.error_message}"
  res.steps.each { |s| puts "  #{s[:passed] ? '✓' : '✗'} #{s[:name]}: #{s[:detail]}" }
end

assert res.success == true, "Legitimate order succeeded"
assert res.order.present?, "Order record created"
assert res.order.total_amount == (product.price * 2), "Order total calculated correctly ($#{res.order.total_amount})"
assert res.response_packet.present?, "Response Trust Packet generated"
assert res.response_packet["signatures"].present?, "Response Trust Packet is signed"
assert product.reload.stock == (initial_stock - 2), "Inventory stock decremented"

# Test 2: Tamper Attack (Payload modified after signature)
puts "\n[Test 2] Tamper Attack Detection"
tampered_packet = client.build_tampered_packet(sku: product.sku, quantity: 1, forged_quantity: 50)
res_tamper = UnikeyService::OrderProcessor.process(tampered_packet)

assert res_tamper.success == false, "Tampered packet rejected"
assert res_tamper.error_code == :invalid_signature, "Rejected with invalid signature"
assert res_tamper.steps.any? { |s| s[:name] == "Cryptographic Signature" && !s[:passed] }, "Audit log recorded cryptographic failure"

# Test 3: Replay Attack (Resending the exact same packet)
puts "\n[Test 3] Replay Attack Prevention"
res_replay = UnikeyService::OrderProcessor.process(legit_packet.to_h)

assert res_replay.success == false, "Replay rejected"
assert res_replay.error_code == :replay_attack, "Rejected as replay attack"
assert res_replay.steps.any? { |s| s[:name] == "Replay Protection" && !s[:passed] }, "Audit log recorded replay prevention"

# Test 4: Expired Packet Attack
puts "\n[Test 4] Expired Packet Detection"
expired_packet = client.build_expired_packet(sku: product.sku, quantity: 1)
res_expired = UnikeyService::OrderProcessor.process(expired_packet)

assert res_expired.success == false, "Expired packet rejected"
assert res_expired.error_code == :expired_packet, "Rejected as expired"

# Test 5: Budget Scope Exceeded
puts "\n[Test 5] Budget / Spending Scope Enforcement"
# Product price is $250 for Enterprise License, but agent packet scope is max $50
ent_product = Product.find_by!(sku: "ENT-GATEWAY-MO")
overbudget_packet = client.build_purchase_packet(sku: ent_product.sku, quantity: 1, max_budget: 50.0)
res_budget = UnikeyService::OrderProcessor.process(overbudget_packet.to_h)

assert res_budget.success == false, "Over-budget order rejected"
assert res_budget.error_code == :budget_exceeded, "Rejected due to budget limit"

# Test 6: Revoked Agent Identity
puts "\n[Test 6] Revoked Identity Rejection"
revoked_agent = AgentIdentity.find_by!(domain: "rogue-agent.xyz")
revoked_client = UnikeyService::ClientAgent.for_agent(revoked_agent)
revoked_packet = revoked_client.build_purchase_packet(sku: product.sku, quantity: 1)
res_revoked = UnikeyService::OrderProcessor.process(revoked_packet.to_h)

assert res_revoked.success == false, "Revoked agent request rejected"
assert res_revoked.error_code == :identity_revoked, "Rejected due to revoked status"

puts "\n========================================================"
puts "  ALL 6 SELF-CHECK TESTS PASSED SUCCESSFULLY! (100% OK)"
puts "========================================================\n"
