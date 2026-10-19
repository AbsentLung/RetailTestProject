require "application_system_test_case"

class IndexSortTest < ApplicationSystemTestCase
  test "sorting the products index doesn't reload the page" do
    honeydukes = Brand.create!(name: "Honeydukes Sweetshop")
    Product.create!(name: "Zonko's Joke Box", brand: honeydukes)
    Product.create!(name: "Acid Pops", brand: honeydukes)

    visit products_path
    page.execute_script("window.name = 'still-the-same-page'")

    click_link "Name"

    # assert_current_path polls like assert_selector does - a plain
    # page.current_url check doesn't wait, and can read the URL before the
    # async fetch-and-swap's history.pushState has actually run yet.
    assert_current_path(/sort=name/, url: true)
    assert_selector "tbody tr", minimum: 1
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
  end

  test "sorting the stores index doesn't reload the page" do
    Store.create!(address: "1 Zonko St")
    Store.create!(address: "1 Acid Ave")

    visit stores_path
    page.execute_script("window.name = 'still-the-same-page'")

    click_link "Address"

    assert_current_path(/sort=address/, url: true)
    assert_selector "tbody tr", minimum: 1
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
  end

  test "sorting the brands index doesn't reload the page" do
    Brand.create!(name: "Zonko's")
    Brand.create!(name: "Honeydukes")

    visit brands_path
    page.execute_script("window.name = 'still-the-same-page'")

    click_link "Name"

    assert_current_path(/sort=name/, url: true)
    assert_selector "tbody tr", minimum: 1
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
  end
end
