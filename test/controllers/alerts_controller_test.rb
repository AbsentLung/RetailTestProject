require "test_helper"

class AlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @brand_a = Brand.create!(name: "Brand A")
    @brand_b = Brand.create!(name: "Brand B")
    @store = Store.create!(address: "1 Filter St")

    @open_alert = make_alert(brand: @brand_a)
    @resolved_alert = make_alert(brand: @brand_b)
    @resolved_alert.update!(resolved_at: 1.day.ago)
  end

  test "no filters shows every alert" do
    get alerts_path
    assert_response :success
    assert_select "tbody tr", 2
  end

  test "status=open shows only unresolved alerts" do
    get alerts_path(status: "open")
    assert_response :success
    assert_match @open_alert.product.name, response.body
    assert_no_match @resolved_alert.product.name, response.body
  end

  test "status=resolved shows only resolved alerts" do
    get alerts_path(status: "resolved")
    assert_response :success
    assert_match @resolved_alert.product.name, response.body
    assert_no_match @open_alert.product.name, response.body
  end

  test "an unrecognized status value is ignored, not an error" do
    get alerts_path(status: "bogus")
    assert_response :success
    assert_select "tbody tr", 2
  end

  test "brand_id filters to that brand's alerts only" do
    get alerts_path(brand_id: @brand_a.id)
    assert_response :success
    assert_match @open_alert.product.name, response.body
    assert_no_match @resolved_alert.product.name, response.body
  end

  test "status and brand_id combine" do
    get alerts_path(status: "resolved", brand_id: @brand_a.id)
    assert_response :success
    assert_select "tbody tr", 0
    assert_select ".empty-state"
  end

  test "pagination links preserve the active filters" do
    get alerts_path(status: "open")
    assert_response :success
    assert_select "select#status option[value='open'][selected]"
  end

  test "Next doesn't appear when everything fits on one page" do
    get alerts_path
    assert_response :success
    assert_select "nav.pagination", false
  end

  test "a malformed cursor falls back to the first page instead of erroring" do
    get alerts_path(after: "garbage")
    assert_response :success
    assert_select "tbody tr", 2
  end

  test "following Next shows the next batch, and preserves the active status filter" do
    brand = Brand.create!(name: "Volume Brand")
    (KeysetPage::LIMIT + 5).times { |n| make_alert(brand: brand, label: n) }

    get alerts_path(status: "open")
    assert_response :success
    assert_select "nav.pagination a", text: /Next/

    next_link = css_select("nav.pagination a").find { |a| a.text =~ /Next/ }["href"]
    get next_link
    assert_response :success
    assert_select "select#status option[value='open'][selected]"
  end

  test "CSV export includes every matching alert, not just one page" do
    get alerts_path(format: :csv), params: { status: "open" }
    assert_response :success
    assert_equal "text/csv", response.media_type

    rows = CSV.parse(response.body, headers: true)
    assert_equal 1, rows.size
    assert_equal @open_alert.product.name, rows.first["Product"]
    assert_not response.body.include?(@resolved_alert.product.name)
  end

  test "CSV export respects brand_id too" do
    get alerts_path(format: :csv), params: { brand_id: @brand_b.id }
    assert_response :success

    rows = CSV.parse(response.body, headers: true)
    assert_equal 1, rows.size
    assert_equal @resolved_alert.product.name, rows.first["Product"]
  end

  private

  def make_alert(brand:, label: nil)
    name = label.nil? ? "Product for #{brand.name}" : "Product for #{brand.name} ##{label}"
    product = Product.create!(name: name, brand: brand)
    first = TrackingEvent.create!(product: product, store: @store, event_time: 2.days.ago, inventory_present: false)
    second = TrackingEvent.create!(product: product, store: @store, event_time: 1.day.ago, inventory_present: false)
    Alert.create!(brand: brand, product: product, store: @store, first_event: first, second_event: second, triggered_at: second.event_time)
  end
end
