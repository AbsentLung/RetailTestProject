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

  test "sorting the tracking-events list by brand name orders alphabetically, and brand links to the brand page" do
    brand_a = Brand.create!(name: "AAA Brand")
    brand_z = Brand.create!(name: "ZZZ Brand")
    product_a = Product.create!(name: "Product under AAA", brand: brand_a)
    product_z = Product.create!(name: "Product under ZZZ", brand: brand_z)
    TrackingEvent.create!(product: product_z, store: @store, event_time: 2.days.ago, inventory_present: true)
    TrackingEvent.create!(product: product_a, store: @store, event_time: 1.day.ago, inventory_present: true)

    get store_path(@store, event_sort: "brand", event_direction: "asc")
    assert_response :success
    names = css_select("tbody tr td:nth-child(4)").map(&:text)
    assert_equal names.sort, names
    assert_select "tbody tr:first-child td:nth-child(4) a[href=?]", brand_path(brand_a), text: brand_a.name
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

  test "q searches stores by address substring" do
    Store.create!(address: "7 Green Dragon Lane, Bywater")
    Store.create!(address: "3 Prancing Pony Way, Bree")

    get stores_path(q: "Dragon")
    assert_response :success
    assert_match "Green Dragon Lane", response.body
    assert_no_match "Prancing Pony", response.body
  end

  test "q is case-insensitive" do
    Store.create!(address: "7 Green Dragon Lane, Bywater")

    get stores_path(q: "dragon")
    assert_response :success
    assert_match "Green Dragon Lane", response.body
  end

  test "a literal % in q is searched for literally, not as a wildcard" do
    Store.create!(address: "50% Off Street")
    Store.create!(address: "500 Main Street")

    get stores_path(q: "50%")
    assert_response :success
    assert_match "50% Off Street", response.body
    assert_no_match "500 Main Street", response.body
  end

  test "no q shows every store" do
    Store.create!(address: "7 Green Dragon Lane, Bywater")

    get stores_path
    assert_response :success
    assert_match "1 Stores Test Ave", response.body
    assert_match "Green Dragon Lane", response.body
  end
end
