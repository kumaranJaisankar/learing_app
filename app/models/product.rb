class Product < ApplicationRecord
  has_many :orders, dependent: :restrict_with_error

  validates :name, :sku, :price, :stock, presence: true
  validates :sku, uniqueness: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :stock, numericality: { greater_than_or_equal_to: 0 }
end
