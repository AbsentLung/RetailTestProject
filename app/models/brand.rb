class Brand < ApplicationRecord
  has_many :products
  has_many :alerts

  validates :name, presence: true, uniqueness: true
end
