require "test_helper"
require "tempfile"

module PriceChecks
  class CsvImporterTest < ActiveSupport::TestCase
    setup do
      @brand = Brand.create!(name: "Test Brand")
      @product = Product.create!(name: "Test Product", brand: @brand)
      @store = Store.create!(address: "123 Test St")
    end

    def write_csv(rows)
      file = Tempfile.new(["price_checks", ".csv"])
      file.write("Address,Product Name,Date,Price Cents\n")
      rows.each { |row| file.write(row.join(",") + "\n") }
      file.flush
      file
    end

    test "a leading zero in Price Cents is parsed as decimal, not octal" do
      file = write_csv([[@store.address, @product.name, "2025-01-01", "0100"]])

      CsvImporter.new(file.path).call

      assert_equal 100, PriceCheck.first.price_cents
    end

    test "a row with a blank price cell is skipped, not fatal" do
      file = write_csv([
        [@store.address, @product.name, "2025-01-01", "500"],
        [@store.address, @product.name, "2025-01-02", ""],
      ])

      CsvImporter.new(file.path).call

      assert_equal 1, PriceCheck.count
      assert CsvImport.exists?(row_count: 1), "expected the successfully-imported row to be counted, skipping the blank-price one"
    end
  end
end
