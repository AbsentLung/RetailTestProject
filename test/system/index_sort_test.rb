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

  test "Back after sorting, then leaving the page via a real link, returns to the sorted list - not a swapped-in fragment on the wrong page" do
    honeydukes = Brand.create!(name: "Honeydukes Sweetshop")
    product_a = Product.create!(name: "Acid Pops", brand: honeydukes)
    Product.create!(name: "Zonko's Joke Box", brand: honeydukes)

    visit products_path
    click_link "Name"
    assert_current_path(/sort=name/, url: true)
    assert_selector "tbody tr:first-child td:first-child", text: "Zonko's Joke Box"

    # "View" is a real link, not wired to live-search at all - with Turbo
    # Drive left on, Turbo would navigate here on its own terms and later
    # ignore the Back navigation back to the sorted list (that history entry
    # came from live-search's own pushState, not from a Turbo visit),
    # leaving this page's own content on screen under the wrong URL - or, if
    # a live-search controller happened to be mounted here too, having it
    # hear the stale popstate and swap the *products list* into this page.
    click_link "View", href: product_path(product_a)
    assert_text product_a.name

    page.go_back

    assert_current_path(/sort=name/, url: true)
    assert_selector "tbody tr:first-child td:first-child", text: "Zonko's Joke Box"
    # Confirms this is actually the products index, not the product show
    # page left on screen (or a mix of the two) - "Acid Pops" legitimately
    # appears as a row in the restored index too, so checking for its
    # absence wouldn't catch either failure mode; the page heading would.
    assert_selector "h1", text: "Products", exact_text: true
  end
end
