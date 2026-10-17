require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "requires an address" do
    assert_not Store.new.valid?
  end

  test "address must be unique" do
    Store.create!(address: "1 Main St")
    assert_not Store.new(address: "1 Main St").valid?
  end
end
