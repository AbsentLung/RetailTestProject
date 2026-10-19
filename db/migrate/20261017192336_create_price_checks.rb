class CreatePriceChecks < ActiveRecord::Migration[7.1]
  def change
    create_table :price_checks do |t|
      # index: false on both - the composite indexes below already cover product_id/store_id
      # lookups as a leading column, so a separate single-column index would be redundant
      # (the same mistake already found and fixed once on tracking_events).
      t.references :product, null: false, foreign_key: true, index: false
      t.references :store, null: false, foreign_key: true, index: false
      t.datetime :event_time, null: false
      t.integer :price_cents, null: false

      t.timestamps
    end
    add_index :price_checks, [:product_id, :event_time]
    add_index :price_checks, [:store_id, :event_time]
  end
end
