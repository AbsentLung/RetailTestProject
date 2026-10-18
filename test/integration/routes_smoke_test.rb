require "test_helper"

class RoutesSmokeTest < ActionDispatch::IntegrationTest
  test "the application eager loads without a syntax or load error" do
    # bin/rails test alone wouldn't catch this: config.eager_load is only
    # true under CI, so a broken file outside the autoload path app code
    # already exercises (like a helper) can sit unnoticed until boot.
    Rails.application.eager_load!
  end

  test "every route renders successfully" do
    brand = Brand.create!(name: "Smoke Brand")
    product = Product.create!(name: "Smoke Product", brand: brand)
    store = Store.create!(address: "1 Smoke St")
    TrackingEvent.create!(product: product, store: store, event_time: 2.days.ago, inventory_present: false)
    TrackingEvent.create!(product: product, store: store, event_time: 1.day.ago, inventory_present: false)
    AlertGenerator.new.call
    alert = Alert.first

    get root_path
    assert_response :success

    get products_path
    assert_response :success
    get product_path(product)
    assert_response :success

    get stores_path
    assert_response :success
    get store_path(store)
    assert_response :success

    get brands_path
    assert_response :success
    get brand_path(brand)
    assert_response :success

    get alerts_path
    assert_response :success
    get alert_path(alert)
    assert_response :success
  end
end
