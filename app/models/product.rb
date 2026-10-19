class Product < ApplicationRecord
  belongs_to :brand
  has_many :tracking_events
  has_many :price_checks
  has_many :alerts

  # Globally unique, not scoped to brand_id: tracking_events.csv has no brand
  # column, so the importer can only ever resolve a product by name alone.
  validates :name, presence: true, uniqueness: true
end
