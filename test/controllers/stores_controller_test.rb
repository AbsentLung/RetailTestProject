require "test_helper"

class StoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = Store.create!(address: "1 Stores Test Ave")
    @brand = Brand.create!(name: "Stores Test Brand")
    @product = Product.create!(name: "Stores Test Product", brand: @brand)
  end

  test "inventory_present filters the tracking-events list" do
    TrackingEvent.create!(product: @product, store: @store, event_time: 2.days.ago, inventory_present: true)
    TrackingEvent.create!(product: @product, store: @store, event_time: 1.day.ago, inventory_present: false)

    get store_path(@store, inventory_present: "no")
    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody td", text: "No"
  end

  test "sorting the tracking-events list by product name orders alphabetically" do
    product_a = Product.create!(name: "AAA Product", brand: @brand)
    product_z = Product.create!(name: "ZZZ Product", brand: @brand)
    TrackingEvent.create!(product: product_z, store: @store, event_time: 2.days.ago, inventory_present: true)
    TrackingEvent.create!(product: product_a, store: @store, event_time: 1.day.ago, inventory_present: true)

    get store_path(@store, event_sort: "product", event_direction: "asc")
    assert_response :success
    names = css_select("tbody tr td:nth-child(3)").map(&:text)
    assert_equal names.sort, names
  end

  test "product_id filters to that product's events only" do
    other_product = Product.create!(name: "Other Product", brand: @brand)
    TrackingEvent.create!(product: @product, store: @store, event_time: 2.days.ago, inventory_present: true)
    TrackingEvent.create!(product: other_product, store: @store, event_time: 1.day.ago, inventory_present: true)

    get store_path(@store, product_id: @product.id)
    assert_response :success
    assert_select "tbody tr", 1
    # Checking the whole page would wrongly fail: the filter dropdown's own
    # option list legitimately includes every product, not just the one
    # currently selected - only the table rows should be scoped.
    assert_select "tbody", text: /#{@product.name}/
    assert_select "tbody", text: /#{other_product.name}/, count: 0
  end

  test "a malformed date doesn't error, just doesn't filter" do
    TrackingEvent.create!(product: @product, store: @store, event_time: 1.day.ago, inventory_present: true)

    get store_path(@store, to: "garbage")
    assert_response :success
    assert_select "tbody tr", 1
  end
end
