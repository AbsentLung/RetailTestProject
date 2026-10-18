require "test_helper"
require "tempfile"

module TrackingEvents
  class CsvImporterTest < ActiveSupport::TestCase
    setup do
      @brand = Brand.create!(name: "Test Brand")
      @product = Product.create!(name: "Test Product", brand: @brand)
      @store = Store.create!(address: "123 Test St")
    end

    def write_csv(rows)
      file = Tempfile.new(["tracking_events", ".csv"])
      file.write("Address,Product Name,Date,Inventory Present\n")
      rows.each { |row| file.write(row.join(",") + "\n") }
      file.flush
      file
    end

    test "imports matching rows and skips rows with no matching store or product" do
      file = write_csv([
        [@store.address, @product.name, "2025-01-01", "True"],
        ["Unknown Address", @product.name, "2025-01-02", "True"],
      ])

      CsvImporter.new(file.path).call

      assert_equal 1, TrackingEvent.count
      assert_equal 1, CsvImport.count
    end

    test "re-running the same file is a no-op" do
      file = write_csv([[@store.address, @product.name, "2025-01-01", "True"]])

      CsvImporter.new(file.path).call
      CsvImporter.new(file.path).call

      assert_equal 1, TrackingEvent.count
      assert_equal 1, CsvImport.count
    end

    test "a row with an unrecognized inventory value is skipped, not fatal" do
      file = write_csv([
        [@store.address, @product.name, "2025-01-01", "True"],
        [@store.address, @product.name, "2025-01-02", "maybe"],
      ])

      CsvImporter.new(file.path).call

      assert_equal 1, TrackingEvent.count
      assert CsvImport.exists?(row_count: 1), "expected the successfully-imported row to be counted, skipping the bad one"
    end

    test "a row with a blank date cell is skipped, not fatal" do
      file = write_csv([
        [@store.address, @product.name, "2025-01-01", "True"],
        [@store.address, @product.name, "", "True"],
      ])

      CsvImporter.new(file.path).call

      assert_equal 1, TrackingEvent.count
      assert CsvImport.exists?(row_count: 1), "expected the successfully-imported row to be counted, skipping the blank-date one"
    end

    test "a blank inventory value is skipped, not silently treated as false" do
      file = write_csv([
        [@store.address, @product.name, "2025-01-01", "True"],
        [@store.address, @product.name, "2025-01-02", ""],
      ])

      CsvImporter.new(file.path).call

      assert_equal 1, TrackingEvent.count
      assert CsvImport.exists?(row_count: 1), "a blank inventory cell is bad data, not a real no-inventory reading - it should be skipped, not recorded as false"
    end

    test "an unexpected failure during import is reported, rolled back, and still raised" do
      file = write_csv([[@store.address, @product.name, "2025-01-01", "True"]])
      reported = nil

      ErrorReporter.stub(:notify, ->(exception, context: {}) { reported = exception }) do
        AlertGenerator.stub(:new, ->(*) { raise "boom" }) do
          assert_raises(RuntimeError) { CsvImporter.new(file.path).call }
        end
      end

      assert_equal "boom", reported.message
      assert_equal 0, TrackingEvent.count, "the transaction should have rolled back, not left a partial import"
    end

    test "an alert-generation failure during import is reported exactly once" do
      file = write_csv([[@store.address, @product.name, "2025-01-01", "False"]])
      generator = AlertGenerator.new(report_errors: false)

      generator.stub(:run, ->(**) { raise "boom" }) do
        AlertGenerator.stub(:new, ->(*) { generator }) do
          assert_difference "ActionMailer::Base.deliveries.size", 1 do
            assert_raises(RuntimeError) { CsvImporter.new(file.path).call }
          end
        end
      end

      assert_equal 0, TrackingEvent.count, "the transaction should have rolled back, not left a partial import"

      mail = ActionMailer::Base.deliveries.last
      assert_match "CsvImporter", mail.body.to_s, "the one email sent should carry the importer's context (file path, rows so far), not just AlertGenerator's"
    end

    test "importing triggers alert generation" do
      file = write_csv([
        [@store.address, @product.name, "2025-01-01", "False"],
        [@store.address, @product.name, "2025-01-02", "False"],
      ])

      CsvImporter.new(file.path).call

      assert_equal 1, Alert.count
    end
  end
end
