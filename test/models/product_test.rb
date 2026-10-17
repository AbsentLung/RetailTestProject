require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @brand = Brand.create!(name: "Acme")
  end

  test "requires a name" do
    assert_not Product.new(brand: @brand).valid?
  end

  # The importer resolves a product by name alone - tracking_events.csv has no
  # brand column - so uniqueness has to be global, not scoped to brand_id.
  test "name must be globally unique, not scoped to brand" do
    Product.create!(name: "Widget", brand: @brand)
    other_brand = Brand.create!(name: "Other Brand")

    assert_not Product.new(name: "Widget", brand: other_brand).valid?
  end
end
