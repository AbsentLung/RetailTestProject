require "csv"
require "digest"
require "zlib"

module Importers
  class BaseCsvImporter
    BATCH_SIZE = 5_000

    def initialize(path)
      @path = path
    end

    def call
      checksum = Digest::SHA256.file(@path).hexdigest
      return if CsvImport.exists?(checksum: checksum)

      stores_by_address = Store.all.index_by(&:address)
      products_by_name  = Product.all.index_by(&:name)
      batch = []
      created_count = 0
      skipped_count = 0

      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(#{lock_id})")
        next if CsvImport.exists?(checksum: checksum) # another run may have just finished while this one waited

        CSV.foreach(@path, headers: true, encoding: "bom|utf-8") do |row|
          store   = stores_by_address[row["Address"]]
          product = products_by_name[row["Product Name"]]
          unless store && product
            skipped_count += 1
            next
          end

          begin
            attrs = row_attributes(row, store, product)
          rescue ArgumentError, TypeError => e
            # TypeError: Ruby's CSV library returns nil, not "", for a blank cell -
            # Date.parse(nil) and Integer(nil) both raise TypeError, not ArgumentError.
            # Scoped to row_attributes only - insert_all below must never be caught
            # here, or a real batch-insert failure would look like "skip one row".
            skipped_count += 1
            Rails.logger.warn("[#{self.class.name}] skipped row #{created_count + skipped_count}: #{e.message}")
            next
          end

          batch << attrs
          created_count += 1

          if batch.size >= BATCH_SIZE
            model_class.insert_all(batch)
            batch.clear
          end
        end

        model_class.insert_all(batch) if batch.any?

        # Right after a TRUNCATE, Postgres still thinks this table has 0 rows (TRUNCATE
        # resets pg_class.reltuples immediately, and autovacuum can't see uncommitted rows
        # from this transaction). Without this, a query planned later in the same transaction
        # — like AlertGenerator's window-function query below — can get planned against a
        # table that looks empty, picking a plan that's fine for 0 rows and bad for 1,000,000.
        # ANALYZE (unlike VACUUM) is allowed inside a transaction block and sees its own writes.
        ActiveRecord::Base.connection.execute("ANALYZE #{model_class.table_name}")

        CsvImport.create!(checksum: checksum, row_count: created_count)
        after_import
      end

      Rails.logger.info "[#{self.class.name}] created=#{created_count} skipped=#{skipped_count}"
    end

    private

    def lock_id
      Zlib.crc32(self.class.name)
    end

    # Subclasses implement these three:
    def model_class
      raise NotImplementedError
    end

    def row_attributes(row, store, product)
      raise NotImplementedError
    end

    def after_import
      # no-op by default
    end
  end
end
