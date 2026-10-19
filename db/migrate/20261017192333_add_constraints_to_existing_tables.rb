class AddConstraintsToExistingTables < ActiveRecord::Migration[7.1]
  def change
    change_column_null :brands, :name, false
    change_column_null :products, :name, false
    change_column_null :stores, :address, false
    change_column_null :tracking_events, :event_time, false
    change_column_null :tracking_events, :inventory_present, false

    add_index :products, :name, unique: true
    add_index :stores, :address, unique: true
  end
end
