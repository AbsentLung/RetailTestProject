class AddPriceCentsCheckConstraint < ActiveRecord::Migration[7.1]
  def change
    # insert_all skips validations, so a negative price from a bad CSV row would
    # otherwise write straight past Rails and into the table unchecked.
    add_check_constraint :price_checks, "price_cents >= 0", name: "price_checks_price_cents_non_negative"
  end
end
