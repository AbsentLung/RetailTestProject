require "test_helper"

class AlertGeneratorTest < ActiveSupport::TestCase
  setup do
    @brand = Brand.create!(name: "Test Brand")
    @product = Product.create!(name: "Test Product", brand: @brand)
    @store = Store.create!(address: "123 Test St")
  end

  def event(event_time, present)
    TrackingEvent.create!(product: @product, store: @store, event_time: event_time, inventory_present: present)
  end

  test "two consecutive no-inventory events create one alert" do
    event("2025-01-01", true)
    e2 = event("2025-01-02", false)
    e3 = event("2025-01-03", false)

    AlertGenerator.new.call

    assert_equal 1, Alert.count
    alert = Alert.first
    assert_equal e2.id, alert.first_event_id
    assert_equal e3.id, alert.second_event_id
    assert_equal @brand.id, alert.brand_id
  end

  test "a three-in-a-row streak produces one alert, not two" do
    event("2025-01-01", false)
    event("2025-01-02", false)
    event("2025-01-03", false)

    AlertGenerator.new.call

    assert_equal 1, Alert.count
  end

  test "out-of-order arrival: rows inserted in reverse chronological order still order by event_time, not id" do
    # Insert the LATER event first, so its id is lower than the earlier event's id.
    # If the generator ordered by id instead of event_time, this would be missed or misordered.
    later   = event("2025-01-05", false)
    earlier = event("2025-01-04", false)

    assert earlier.id > later.id, "setup assumption: earlier event has the higher id"

    AlertGenerator.new.call

    assert_equal 1, Alert.count
    alert = Alert.first
    assert_equal earlier.id, alert.first_event_id
    assert_equal later.id, alert.second_event_id
  end

  test "same-day ties use id as the explicit tiebreak" do
    same_day = Date.new(2025, 1, 1)
    first  = event(same_day, false)
    second = event(same_day, false)

    AlertGenerator.new.call

    assert_equal 1, Alert.count
    alert = Alert.first
    assert_equal first.id, alert.first_event_id
    assert_equal second.id, alert.second_event_id
  end

  test "a price check between two no-inventory events does not interfere" do
    event("2025-01-01", false)
    event("2025-01-02", false)
    # price_checks live in their own table entirely - AlertGenerator never queries it.
    PriceCheck.create!(product: @product, store: @store, event_time: "2025-01-01T12:00:00", price_cents: 500)

    AlertGenerator.new.call

    assert_equal 1, Alert.count
  end

  test "resolved_at is set to the next true reading, skipping over additional falses in a longer streak" do
    event("2025-01-01", false)
    event("2025-01-02", false) # second event of the alert
    event("2025-01-03", false) # continuation, not a new alert
    resolving = event("2025-01-04", true)

    AlertGenerator.new.call

    alert = Alert.first
    assert_equal resolving.event_time, alert.resolved_at
  end

  test "resolved_at is nil when the outage is still ongoing" do
    event("2025-01-01", false)
    event("2025-01-02", false)

    AlertGenerator.new.call

    assert_nil Alert.first.resolved_at
  end

  test "re-running the bulk generator is idempotent" do
    event("2025-01-01", false)
    event("2025-01-02", false)

    AlertGenerator.new.call
    AlertGenerator.new.call

    assert_equal 1, Alert.count
  end

  test "the per-pair generator only touches its own pair" do
    other_product = Product.create!(name: "Other Product", brand: @brand)
    event("2025-01-01", false)
    event("2025-01-02", false)
    TrackingEvent.create!(product: other_product, store: @store, event_time: "2025-02-01", inventory_present: false)
    TrackingEvent.create!(product: other_product, store: @store, event_time: "2025-02-02", inventory_present: false)

    AlertGenerator.new.call
    assert_equal 2, Alert.count

    AlertGenerator.new(product_id: @product.id, store_id: @store.id).call

    assert_equal 2, Alert.count, "the other pair's alert should be untouched"
  end

  test "a late true arriving between two previously-adjacent false events removes that alert on regeneration" do
    event("2025-01-01", false)
    e2 = event("2025-01-02", false)

    AlertGenerator.new(product_id: @product.id, store_id: @store.id).call
    assert_equal 1, Alert.count

    # a late event lands strictly between the two triggering events
    event("2025-01-01T12:00:00", true)

    AlertGenerator.new(product_id: @product.id, store_id: @store.id).call

    assert_equal 0, Alert.count
  end
end
