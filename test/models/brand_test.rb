require "test_helper"

class BrandTest < ActiveSupport::TestCase
  test "requires a name" do
    assert_not Brand.new.valid?
  end

  test "name must be unique" do
    Brand.create!(name: "Acme")
    assert_not Brand.new(name: "Acme").valid?
  end
end
