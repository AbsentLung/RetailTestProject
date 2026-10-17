class FixTrackingEventsIndexes < ActiveRecord::Migration[7.1]
  def change
    # Composite indexes match the actual reads (show pages order by event_time;
    # the alert generator partitions by product_id+store_id, ordered by event_time, id).
    # These make the original single-column FK indexes redundant.
    add_index :tracking_events, [:store_id, :event_time]
    add_index :tracking_events, [:product_id, :event_time]
    add_index :tracking_events, [:product_id, :store_id, :event_time, :id], name: "index_tracking_events_on_product_store_event_id"

    remove_index :tracking_events, :product_id
    remove_index :tracking_events, :store_id
  end
end
