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
        price_cents: Integer(row["Price Cents"])
      }
    end
  end
end
