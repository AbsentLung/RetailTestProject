class Store < ApplicationRecord
  has_many :tracking_events
  has_many :price_checks
  has_many :alerts

  validates :address, presence: true, uniqueness: true
end
