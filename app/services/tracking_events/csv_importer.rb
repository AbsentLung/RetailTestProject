require "csv"

module TrackingEvents
  class CsvImporter
    def initialize(path)
      @path = path
    end

    def call
      row_count = 0
      created_count = 0

      CSV.foreach(@path, headers: true) do |row|
        row_count += 1

        store   = Store.find_by(address: row["Address"])
        product = Product.find_by(name: row["Product Name"])

        # If there's bad data, just skip it (or you could log it)
        next unless store && product

        event_time       = Date.parse(row["Date"])
        inventory_present = cast_boolean(row["Inventory Present"])

        TrackingEvent.create!(
          store: store,
          product: product,
          event_time: event_time,
          inventory_present: inventory_present
        )

        created_count += 1
      end

      Rails.logger.info "[TrackingEvents::CsvImporter] rows processed=#{row_count} created=#{created_count}"
    end

    private

    def cast_boolean(value)
      case value
      when true, "true", "TRUE", "t", "T", "1", "True" then true
      else false
      end
    end
  end
end