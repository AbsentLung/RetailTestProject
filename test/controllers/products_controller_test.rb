require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(name: "Keyset Scroll Product", brand: Brand.create!(name: "Keyset Scroll Brand"))
    @store = Store.create!(address: "1 Keyset Scroll Ave")
  end

  test "a malformed cursor on the tracking-events list falls back to the first page instead of erroring" do
    TrackingEvent.create!(product: @product, store: @store, event_time: 1.day.ago, inventory_present: true)

    get product_path(@product, after: "garbage")
    assert_response :success
    assert_select "tbody tr", 1
  end

  test "Next appears once tracking events exceed one page, and following it shows the rest" do
    (KeysetPage::LIMIT + 5).times do |n|
      TrackingEvent.create!(product: @product, store: @store, event_time: (n + 1).hours.ago, inventory_present: true)
    end

    get product_path(@product)
    assert_response :success
    assert_select "nav.pagination a", text: /Next/

    next_link = css_select("nav.pagination a").find { |a| a.text =~ /Next/ }["href"]
    get next_link
    assert_response :success
    assert_select "tbody tr", 5
  end

  test "inventory_present filters the tracking-events list" do
    TrackingEvent.create!(product: @product, store: @store, event_time: 2.days.ago, inventory_present: true)
    TrackingEvent.create!(product: @product, store: @store, event_time: 1.day.ago, inventory_present: false)

    get product_path(@product, inventory_present: "yes")
    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody td", text: "Yes"
  end

  test "a date range filters the tracking-events list to that window" do
    TrackingEvent.create!(product: @product, store: @store, event_time: Time.zone.local(2026, 1, 1), inventory_present: true)
    TrackingEvent.create!(product: @product, store: @store, event_time: Time.zone.local(2026, 6, 1), inventory_present: true)

    get product_path(@product, from: "2026-01-01", to: "2026-01-02")
    assert_response :success
    assert_select "tbody tr", 1
    assert_select ".empty-state", false
  end

  test "sorting the tracking-events list by store address orders alphabetically" do
    store_a = Store.create!(address: "1 AAA St")
    store_z = Store.create!(address: "1 ZZZ St")
    TrackingEvent.create!(product: @product, store: store_z, event_time: 2.days.ago, inventory_present: true)
    TrackingEvent.create!(product: @product, store: store_a, event_time: 1.day.ago, inventory_present: true)

    get product_path(@product, event_sort: "store", event_direction: "asc")
    assert_response :success
    addresses = css_select("tbody tr td:nth-child(3)").map(&:text)
    assert_equal addresses.sort, addresses
  end

  test "a malformed date doesn't error, just doesn't filter" do
    TrackingEvent.create!(product: @product, store: @store, event_time: 1.day.ago, inventory_present: true)

    get product_path(@product, from: "not-a-date")
    assert_response :success
    assert_select "tbody tr", 1
  end

  test "q searches products by name substring" do
    Product.create!(name: "Chocolate Frogs", brand: @product.brand)
    Product.create!(name: "Bree-Brewed Ale", brand: @product.brand)

    get products_path(q: "Chocolate")
    assert_response :success
    assert_match "Chocolate Frogs", response.body
    assert_no_match "Bree-Brewed", response.body
  end

  test "brand_q searches products by their brand's name substring" do
    honeydukes = Brand.create!(name: "Honeydukes Sweetshop")
    Product.create!(name: "Chocolate Frogs", brand: honeydukes)

    get products_path(brand_q: "Honeydukes")
    assert_response :success
    assert_match "Chocolate Frogs", response.body
    assert_no_match @product.name, response.body
  end

  test "q and brand_q combine" do
    honeydukes = Brand.create!(name: "Honeydukes Sweetshop")
    match = Product.create!(name: "Chocolate Frogs", brand: honeydukes)
    wrong_brand = Product.create!(name: "Chocolate Something", brand: @product.brand)
    wrong_name = Product.create!(name: "Cauldron Cakes", brand: honeydukes)

    get products_path(q: "Chocolate", brand_q: "Honeydukes")
    assert_response :success
    assert_select "tbody", text: /#{match.name}/
    assert_select "tbody", text: /#{wrong_brand.name}/, count: 0
    assert_select "tbody", text: /#{wrong_name.name}/, count: 0
  end

  test "a literal % in q is searched for literally, not as a wildcard" do
    Product.create!(name: "50% Off Widget", brand: @product.brand)
    Product.create!(name: "500 Widget", brand: @product.brand)

    get products_path(q: "50%")
    assert_response :success
    assert_match "50% Off Widget", response.body
    assert_no_match "500 Widget", response.body
  end
end
