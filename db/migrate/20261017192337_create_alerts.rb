class CreateAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :alerts do |t|
      t.references :brand, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.bigint :first_event_id, null: false
      t.bigint :second_event_id, null: false
      t.datetime :triggered_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    # A given event can be the second (triggering) event of at most one alert,
    # given the one-alert-per-streak rule - a unique index on second_event_id alone
    # is enough; a wider composite would be redundant.
    add_index :alerts, :second_event_id, unique: true
    add_foreign_key :alerts, :tracking_events, column: :first_event_id
    add_foreign_key :alerts, :tracking_events, column: :second_event_id
  end
end
