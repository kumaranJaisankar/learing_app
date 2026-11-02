class Order < ApplicationRecord
  belongs_to :product
  belongs_to :agent_identity, optional: true
  belongs_to :trust_packet_ledger

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true

  def parsed_response_packet
    @parsed_response_packet ||= JSON.parse(response_packet) rescue {}
  end
end
