# frozen_string_literal: true

require "ed25519"
require "base64"

module UnikeyService
  module ServerKey
    DOMAIN = "cloudstore.local"
    SEED = "cloudstore_local_signing_seed_32" # 32 bytes

    def self.signing_key
      @signing_key ||= Ed25519::SigningKey.new(SEED)
    end

    def self.public_key_b64
      @public_key_b64 ||= Base64.strict_encode64(signing_key.verify_key.to_bytes)
    end

    def self.ensure_registered!
      agent = AgentIdentity.find_or_initialize_by(domain: DOMAIN)
      agent.selector = "unikey"
      agent.public_key = public_key_b64
      agent.authorized_budget = 1_000_000.0
      agent.active = true
      agent.save! if agent.new_record? || agent.changed?
    end
  end
end
