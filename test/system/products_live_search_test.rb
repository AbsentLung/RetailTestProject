require "application_system_test_case"

class ProductsLiveSearchTest < ApplicationSystemTestCase
  test "typing in either search field filters without a page reload, and they combine" do
    honeydukes = Brand.create!(name: "Honeydukes Sweetshop")
    bree = Brand.create!(name: "Bree-Brewed Ale Co")
    Product.create!(name: "Chocolate Frogs", brand: honeydukes)
    Product.create!(name: "Cauldron Cakes", brand: honeydukes)
    Product.create!(name: "Chocolate Something", brand: bree)

    visit products_path
    assert_text "Chocolate Frogs"
    assert_text "Cauldron Cakes"
    assert_text "Chocolate Something"

    page.execute_script("window.name = 'still-the-same-page'")
    fill_in "q", with: "Chocolate"

    assert_text "Chocolate Frogs"
    assert_text "Chocolate Something"
    assert_no_text "Cauldron Cakes"

    fill_in "brand_q", with: "Honeydukes"

    assert_text "Chocolate Frogs"
    assert_no_text "Chocolate Something"
    assert_no_text "Cauldron Cakes"

    assert_equal "still-the-same-page", page.evaluate_script("window.name")
    assert_match(/q=Chocolate/, page.current_url)
    assert_match(/brand_q=Honeydukes/, page.current_url)
  end
end
