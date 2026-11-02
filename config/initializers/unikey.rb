# frozen_string_literal: true

require "unikey"

# Enable mockable DNS lookups:
# Checks database AgentIdentity first for quick offline agent simulation,
# then falls back to real live DNS TXT query (unikey._domainkey.<domain>).
module MockableDnsLookup
  def fetch_from_dns(signer_domain)
    # Check local AgentIdentity registry first
    agent = AgentIdentity.find_by(domain: signer_domain)
    return agent.public_key if agent&.public_key.present?

    # Fall back to live public DNS
    super
  end
end

UniKey::DNS.singleton_class.prepend(MockableDnsLookup)

UniKey.configure do |config|
  config.dns_cache_ttl = 300 # 5 minutes
  config.max_request_age = 300 # 5 minutes
  config.dns_hardening_enabled = false # Disabled for local dev/testing
end
