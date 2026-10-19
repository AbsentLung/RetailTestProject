require "application_system_test_case"

class AlertsLiveFilterTest < ApplicationSystemTestCase
  test "changing a dropdown filters without a page reload, and the URL still reflects it" do
    brand = Brand.create!(name: "Live Filter Brand")
    store = Store.create!(address: "1 Live Filter Ave")

    open_alert = make_alert(brand: brand, store: store, name: "Open Product")
    resolved_alert = make_alert(brand: brand, store: store, name: "Resolved Product")
    resolved_alert.update!(resolved_at: 1.day.ago)

    visit alerts_path
    assert_text open_alert.product.name
    assert_text resolved_alert.product.name

    # Tag window.name before filtering - it's cleared by a real navigation but
    # survives DOM mutation, so this proves no page load happened.
    page.execute_script("window.name = 'still-the-same-page'")

    select "Open", from: "status"

    assert_text open_alert.product.name
    assert_no_text resolved_alert.product.name
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
    assert_match(/status=open/, page.current_url)
  end

  test "clicking a column header sorts without a page reload" do
    brand_a = Brand.create!(name: "AAA Brand")
    brand_z = Brand.create!(name: "ZZZ Brand")
    store = Store.create!(address: "1 Sort Test Ave")
    make_alert(brand: brand_z, store: store, name: "Z Product")
    make_alert(brand: brand_a, store: store, name: "A Product")

    visit alerts_path
    page.execute_script("window.name = 'still-the-same-page'")

    click_link "Brand"

    # assert_selector (unlike all/map) actually waits for the fetch-and-
    # re-render to finish - reading rows immediately after the click can
    # race the async update and see the pre-click DOM.
    assert_selector "tbody tr:first-child td:first-child", text: "AAA Brand"
    assert_equal ["AAA Brand", "ZZZ Brand"], all("tbody tr td:first-child").map(&:text)
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
    assert_match(/sort=brand/, page.current_url)

    click_link "Brand ▲"

    assert_selector "tbody tr:first-child td:first-child", text: "ZZZ Brand"
    assert_equal ["ZZZ Brand", "AAA Brand"], all("tbody tr td:first-child").map(&:text)
  end

  test "pressing Back after sorting restores the previous order instead of leaving a stale table" do
    brand_a = Brand.create!(name: "AAA Brand")
    brand_z = Brand.create!(name: "ZZZ Brand")
    store = Store.create!(address: "1 Back Button Ave")
    make_alert(brand: brand_z, store: store, name: "Z Product")
    make_alert(brand: brand_a, store: store, name: "A Product")

    visit alerts_path
    assert_selector "tbody tr", count: 2
    original_order = all("tbody tr td:first-child").map(&:text)

    click_link "Brand"
    assert_selector "tbody tr:first-child td:first-child", text: "AAA Brand"

    page.go_back

    # Before a popstate listener existed, history.pushState changed the URL
    # on Back but nothing re-fetched - the table stayed on the sorted-by-
    # brand view even though the address bar said otherwise.
    assert_selector "tbody tr:first-child td:first-child", text: original_order.first
    assert_equal original_order, all("tbody tr td:first-child").map(&:text)
  end

  private

  def make_alert(brand:, store:, name:)
    product = Product.create!(name: name, brand: brand)
    first = TrackingEvent.create!(product: product, store: store, event_time: 2.days.ago, inventory_present: false)
    second = TrackingEvent.create!(product: product, store: store, event_time: 1.day.ago, inventory_present: false)
    Alert.create!(brand: brand, product: product, store: store, first_event: first, second_event: second, triggered_at: second.event_time)
  end
end
