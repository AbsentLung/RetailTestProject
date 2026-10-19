require "application_system_test_case"

class TrackingEventsUxTest < ApplicationSystemTestCase
  test "sorting the tracking-events table lands back on the table, not the top of the page" do
    brand = Brand.create!(name: "UX Test Brand")
    store = Store.create!(address: "1 UX Test Ave")
    product = Product.create!(name: "UX Test Product", brand: brand)
    60.times { |n| TrackingEvent.create!(product: product, store: store, event_time: (n + 1).hours.ago, inventory_present: n.even?) }

    visit product_path(product)
    page.execute_script("window.scrollTo(0, 400)")

    click_link "Event Time"

    assert_selector "tbody tr", minimum: 1
    scroll_y = page.evaluate_script("window.scrollY")
    assert scroll_y > 0, "expected the page to land back on the tracking-events table (scrollY > 0), got #{scroll_y}"
  end

  test "changing a tracking-event filter applies automatically, without clicking Filter, and doesn't scroll to top" do
    brand = Brand.create!(name: "UX Filter Brand")
    store = Store.create!(address: "1 UX Filter Ave")
    product = Product.create!(name: "UX Filter Product", brand: brand)
    60.times { |n| TrackingEvent.create!(product: product, store: store, event_time: (n + 1).hours.ago, inventory_present: n.even?) }

    visit product_path(product)
    assert_selector "tbody tr", count: 50
    page.execute_script("window.scrollTo(0, 400)")

    select "Yes", from: "inventory_present"

    assert_selector "tbody tr", count: 30
    assert_match(/inventory_present=yes/, page.current_url)
    scroll_y = page.evaluate_script("window.scrollY")
    assert scroll_y > 0, "expected the page to land back on the tracking-events table (scrollY > 0), got #{scroll_y}"
  end
end
