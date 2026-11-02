require "ed25519"
require "base64"

puts "== Seeding Products..."

products_data = [
  {
    name: "GPU Compute Block (H100 - 1 Hour)",
    sku: "COMPUTE-H100-1H",
    description: "1 hour of dedicated NVIDIA H100 SXM5 compute with 80GB VRAM.",
    price: 3.50,
    stock: 200
  },
  {
    name: "LLM Token Batch (10M Tokens)",
    sku: "TOKEN-10M",
    description: "High-throughput token inference quota across frontier foundation models.",
    price: 15.00,
    stock: 500
  },
  {
    name: "Autonomous Web Scraping Worker (24h)",
    sku: "WORKER-SCRAPE-24H",
    description: "Managed headless browser cluster worker for automated data collection.",
    price: 25.00,
    stock: 50
  },
  {
    name: "Vector DB Dedicated Index (1GB)",
    sku: "VEC-DB-1GB",
    description: "Low-latency HNSW index instance with real-time vector embeddings search.",
    price: 50.00,
    stock: 30
  },
  {
    name: "Enterprise Agent Gateway License",
    sku: "ENT-GATEWAY-MO",
    description: "Monthly enterprise license for high-concurrency agent orchestration.",
    price: 250.00,
    stock: 10
  }
]

products_data.each do |attrs|
  p = Product.find_or_initialize_by(sku: attrs[:sku])
  p.name = attrs[:name]
  p.description = attrs[:description]
  p.price = attrs[:price]
  p.stock = attrs[:stock]
  p.save!
end

puts "== Seeding Agent Identities with Ed25519 Keypairs..."

# Predefined deterministic 32-byte seeds for repeatable tests
agent_configs = [
  {
    domain: "procure.ai",
    budget: 100.00,
    active: true,
    seed: "procure_ai_seed_0123456789abcdef" # exactly 32 bytes
  },
  {
    domain: "autopilot.corp",
    budget: 500.00,
    active: true,
    seed: "autopilot_corp_seed_0123456789ab" # exactly 32 bytes
  },
  {
    domain: "rogue-agent.xyz",
    budget: 10.00,
    active: false,
    seed: "rogue_agent_xyz_seed_0123456789a" # exactly 32 bytes
  }
]

agent_configs.each do |cfg|
  signing_key = Ed25519::SigningKey.new(cfg[:seed])
  verify_key = signing_key.verify_key

  pub_base64 = Base64.strict_encode64(verify_key.to_bytes)
  priv_base64 = Base64.strict_encode64(signing_key.to_bytes)

  agent = AgentIdentity.find_or_initialize_by(domain: cfg[:domain])
  agent.selector = "unikey"
  agent.public_key = pub_base64
  agent.simulated_private_key = priv_base64
  agent.authorized_budget = cfg[:budget]
  agent.active = cfg[:active]
  agent.save!

  puts "  Agent: #{agent.domain} | PubKey: #{pub_base64[0..12]}... | Budget: $#{agent.authorized_budget} | Active: #{agent.active}"
end

puts "== Seeds completed successfully!"
