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
end
