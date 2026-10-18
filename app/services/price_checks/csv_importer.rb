module PriceChecks
  class CsvImporter < Importers::BaseCsvImporter
    private

    def model_class
      PriceCheck
    end

    def row_attributes(row, store, product)
      {
        store_id: store.id,
        product_id: product.id,
        event_time: Date.parse(row["Date"]),
        # Explicit base 10: Integer() auto-detects a leading "0" as octal,
        # so "0100" would otherwise become 64 cents instead of 100.
        price_cents: Integer(row["Price Cents"], 10)
      }
    end
  end
end
