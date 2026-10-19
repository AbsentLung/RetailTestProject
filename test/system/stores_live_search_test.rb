require "application_system_test_case"

class StoresLiveSearchTest < ApplicationSystemTestCase
  test "typing in the search box filters without a page reload or a submit click" do
    Store.create!(address: "7 Green Dragon Lane, Bywater")
    Store.create!(address: "3 Prancing Pony Way, Bree")

    visit stores_path
    assert_text "Green Dragon Lane"
    assert_text "Prancing Pony"
    assert_no_selector "button", text: "Filter"

    page.execute_script("window.name = 'still-the-same-page'")
    fill_in "q", with: "Dragon"

    assert_text "Green Dragon Lane"
    assert_no_text "Prancing Pony"
    assert_equal "still-the-same-page", page.evaluate_script("window.name")
    assert_match(/q=Dragon/, page.current_url)
  end
end
