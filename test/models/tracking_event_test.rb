require "test_helper"

class TrackingEventTest < ActiveSupport::TestCase
  # No model-level validations here by design: insert_all skips them entirely,
  # so the database's null: false constraints are what actually protect this
  # table, not Rails validations. This confirms the DB layer does its job.
  test "the database rejects a null event_time" do
    brand = Brand.create!(name: "Acme")
    product = Product.create!(name: "Widget", brand: brand)
    store = Store.create!(address: "1 Main St")

    assert_raises(ActiveRecord::NotNullViolation) do
      TrackingEvent.connection.execute(<<~SQL)
        INSERT INTO tracking_events (product_id, store_id, inventory_present, created_at, updated_at)
        VALUES (#{product.id}, #{store.id}, true, now(), now())
      SQL
    end
  end
end
