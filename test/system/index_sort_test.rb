require "application_system_test_case"

class IndexSortTest < ApplicationSystemTestCase
  test "sorting the products index doesn't reload the page, actually reorders the rows, and Back restores the previous order" do
    honeydukes = Brand.create!(name: "Honeydukes Sweetshop")
    Product.create!(name: "Zonko's Joke Box", brand: honeydukes)
    Product.create!(name: "Acid Pops", brand: honeydukes)

    visit products_path
    assert_selector "tbody tr:first-child td:first-child", text: "Acid Pops"
    page.execute_script("window.name = 'still-the-same-page'")

    click_link "Name"

    # assert_current_path polls like assert_selector does - a plain
    # page.current_url check doesn't wait, and can read the URL before the
    # async fetch-and-swap's history.pushState has actually run yet.
    assert_current_path(/sort=name/, url: true)
    assert_selector "tbody tr:first-child td:first-child", text: "Zonko's Joke Box"
    assert_equal "still-the-same-page", page.evaluate_script("window.name")

    page.go_back

    assert_selector "tbody tr:first-child td:first-child", text: "Acid Pops"
    assert_equal "still-the-same-page", page.evaluate_script("window.name"),
      "Back shouldn't trigger a real navigation either - it's a popstate, same as the sort click was a fetch-and-swap"
  end

  test "sorting the stores index doesn't reload the page and actually reorders the rows" do
    Store.create!(address: "1 Zonko St")
    Store.create!(address: "1 Acid Ave")

    visit stores_path
    assert_selector "tbody tr:first-child td:first-child", text: "1 Acid Ave"
    page.execute_script("window.name = 'still-the-same-page'")

    click_link "Address"

    assert_current_path(/sort=address/, url: true)
    assert_selector "tbody tr:first-child td:first-child", text: "1 Zonko St"
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
  end

  test "sorting the brands index doesn't reload the page and actually reorders the rows" do
    Brand.create!(name: "Zonko's")
    Brand.create!(name: "Honeydukes")

    visit brands_path
    assert_selector "tbody tr:first-child td:first-child", text: "Honeydukes"
    page.execute_script("window.name = 'still-the-same-page'")

    click_link "Name"

    assert_current_path(/sort=name/, url: true)
    assert_selector "tbody tr:first-child td:first-child", text: "Zonko's"
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
  end
end
