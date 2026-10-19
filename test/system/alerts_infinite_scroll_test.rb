require "application_system_test_case"

class AlertsInfiniteScrollTest < ApplicationSystemTestCase
  test "scrolling the Next link into view auto-loads the next batch, with no click" do
    brand = Brand.create!(name: "Scroll Test Brand")
    store = Store.create!(address: "1 Scroll Test Ave")
    total = KeysetPage::LIMIT + 10

    total.times do |n|
      product = Product.create!(name: "Scroll Test Product #{n}", brand: brand)
      first = TrackingEvent.create!(product: product, store: store, event_time: (total - n + 1).hours.ago, inventory_present: false)
      second = TrackingEvent.create!(product: product, store: store, event_time: (total - n).hours.ago, inventory_present: false)
      Alert.create!(brand: brand, product: product, store: store, first_event: first, second_event: second, triggered_at: second.event_time)
    end

    visit alerts_path

    assert_selector "tbody[data-infinite-scroll-target='rows'] tr", count: KeysetPage::LIMIT
    assert_selector "a.next-link"

    page.execute_script("document.querySelector('a.next-link').scrollIntoView()")

    assert_selector "tbody[data-infinite-scroll-target='rows'] tr", count: total, wait: 5
    assert_no_selector "a.next-link"
  end
end
