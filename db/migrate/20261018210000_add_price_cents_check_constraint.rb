class AddPriceCentsCheckConstraint < ActiveRecord::Migration[7.1]
  def change
    # A negative price means the file is untrustworthy, not just this one row -
    # insert_all skips validations, so this constraint is what actually stops it,
    # by failing the whole import rather than silently keeping going.
    add_check_constraint :price_checks, "price_cents >= 0", name: "price_checks_price_cents_non_negative"
  end
end
