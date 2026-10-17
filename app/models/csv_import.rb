class CsvImport < ApplicationRecord
  validates :checksum, presence: true, uniqueness: true
  validates :row_count, presence: true
end
