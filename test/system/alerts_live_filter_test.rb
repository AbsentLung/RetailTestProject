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

  private

  def make_alert(brand:, store:, name:)
    product = Product.create!(name: name, brand: brand)
    first = TrackingEvent.create!(product: product, store: store, event_time: 2.days.ago, inventory_present: false)
    second = TrackingEvent.create!(product: product, store: store, event_time: 1.day.ago, inventory_present: false)
    Alert.create!(brand: brand, product: product, store: store, first_event: first, second_event: second, triggered_at: second.event_time)
  end
end
