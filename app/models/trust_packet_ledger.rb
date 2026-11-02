class TrustPacketLedger < ApplicationRecord
  has_one :order, dependent: :destroy

  validates :packet_id, presence: true, uniqueness: true
  validates :signer_domain, :subject, :action, :status, :raw_packet, presence: true

  STATUSES = %w[verified rejected].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :verified, -> { where(status: "verified") }
  scope :rejected, -> { where(status: "rejected") }
  scope :recent, -> { order(created_at: :desc) }

  def parsed_packet
    @parsed_packet ||= JSON.parse(raw_packet) rescue {}
  end

  def verified?
    status == "verified"
  end
end
