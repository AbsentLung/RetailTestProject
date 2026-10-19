class AddKeysetIndexes < ActiveRecord::Migration[7.1]
  def change
    # Keyset pagination on alerts needs the id tiebreak in the index, not just
    # the sort column, to be a single fully-ordered scan - see DESIGN_PROPOSAL_FINAL.md.
    add_index :alerts, [:triggered_at, :id]

    # Same reasoning for tracking events, scoped by product or store. These
    # replace the 2-column indexes from FixTrackingEventsIndexes - any query
    # that used those is still served by the 3-column index's leftmost prefix.
    add_index :tracking_events, [:product_id, :event_time, :id],
      name: "index_tracking_events_on_product_id_and_event_time_and_id"
    remove_index :tracking_events, [:product_id, :event_time],
      name: "index_tracking_events_on_product_id_and_event_time"

    add_index :tracking_events, [:store_id, :event_time, :id],
      name: "index_tracking_events_on_store_id_and_event_time_and_id"
    remove_index :tracking_events, [:store_id, :event_time],
      name: "index_tracking_events_on_store_id_and_event_time"
  end
end
