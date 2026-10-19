require "test_helper"

class BrandsControllerTest < ActionDispatch::IntegrationTest
  test "q searches brands by name substring" do
    Brand.create!(name: "Honeydukes Sweetshop")
    Brand.create!(name: "Gringotts Wizarding Bank")

    get brands_path(q: "Honeydukes")
    assert_response :success
    assert_match "Honeydukes Sweetshop", response.body
    assert_no_match "Gringotts", response.body
  end

  test "q is case-insensitive" do
    Brand.create!(name: "Honeydukes Sweetshop")

    get brands_path(q: "honeydukes")
    assert_response :success
    assert_match "Honeydukes Sweetshop", response.body
  end

  test "a literal % in q is searched for literally, not as a wildcard" do
    Brand.create!(name: "50% Off Co")
    Brand.create!(name: "500 Industries")

    get brands_path(q: "50%")
    assert_response :success
    assert_match "50% Off Co", response.body
    assert_no_match "500 Industries", response.body
  end

  test "no q shows every brand" do
    Brand.create!(name: "Honeydukes Sweetshop")

    get brands_path
    assert_response :success
    assert_match "Honeydukes Sweetshop", response.body
  end
end
