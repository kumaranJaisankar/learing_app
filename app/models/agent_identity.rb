class AgentIdentity < ApplicationRecord
  has_many :orders, dependent: :nullify

  validates :domain, presence: true, uniqueness: true
  validates :selector, :public_key, presence: true
  validates :authorized_budget, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  # Returns the raw binary public key from base64
  def raw_public_key_bytes
    Base64.strict_decode64(public_key)
  end

  # Returns standard OpenSSL::PKey Ed25519 object
  def crypto_public_key
    OpenSSL::PKey.new_raw_public_key("ED25519", raw_public_key_bytes)
  end

  # Standard DNS TXT record format according to UniKey / DKIM spec
  def dns_txt_record
    "v=UNIKEY1; k=ed25519; p=#{public_key}"
  end
end
