module TrackingEvents
  class CsvImporter < Importers::BaseCsvImporter
    private

    def model_class
      TrackingEvent
    end

    def row_attributes(row, store, product)
      {
        store_id: store.id,
        product_id: product.id,
        event_time: Date.parse(row["Date"]),
        inventory_present: cast_boolean(row["Inventory Present"])
      }
    end

    def after_import
      AlertGenerator.new.call
    end

    def cast_boolean(value)
      case value
      when true, "true", "TRUE", "t", "T", "1", "True" then true
      when false, "false", "FALSE", "f", "F", "0", "False", nil, "" then false
      else
        raise ArgumentError, "Unrecognized inventory value: #{value.inspect}"
      end
    end
  end
end
