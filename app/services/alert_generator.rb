# Computes alerts directly from tracking_events with a window function - no
# intermediate counter table, so it works identically whether rows arrived via
# a bulk import or one at a time. One alert per streak, not per pair: the
# prev2 check skips a pair that continues an already-alerted streak rather
# than starting one. Always deletes before regenerating, so re-running never
# leaves stale resolved_at values or orphaned rows behind.
class AlertGenerator
  def initialize(product_id: nil, store_id: nil)
    @product_id = product_id
    @store_id = store_id
  end

  def call
    # Wrapped so a standalone call (no enclosing transaction) can't leave the
    # table empty between delete and regenerate. Joins the import's existing
    # transaction when called from there instead of opening a nested one.
    Alert.transaction do
      if @product_id && @store_id
        Alert.where(product_id: @product_id, store_id: @store_id).delete_all
        run(filter: "WHERE product_id = $1 AND store_id = $2", binds: [@product_id, @store_id])
      else
        Alert.delete_all
        run(filter: "", binds: [])
      end
    end
  end

  private

  def run(filter:, binds:)
    sql = <<~SQL
      INSERT INTO alerts (brand_id, product_id, store_id, first_event_id, second_event_id, triggered_at, resolved_at, created_at, updated_at)
      SELECT p.brand_id, t.product_id, t.store_id, t.first_event_id, t.id, t.event_time, resolved.event_time, now(), now()
      FROM (
        SELECT id, product_id, store_id, event_time, inventory_present,
               LAG(id) OVER w AS first_event_id,
               LAG(inventory_present, 1) OVER w AS prev1,
               LAG(inventory_present, 2) OVER w AS prev2
        FROM tracking_events
        #{filter}
        WINDOW w AS (PARTITION BY product_id, store_id ORDER BY event_time, id)
      ) t
      JOIN products p ON p.id = t.product_id
      LEFT JOIN LATERAL (
        SELECT te.event_time FROM tracking_events te
        WHERE te.product_id = t.product_id AND te.store_id = t.store_id
          AND te.inventory_present = true
          AND (te.event_time, te.id) > (t.event_time, t.id)
        ORDER BY te.event_time, te.id LIMIT 1
      ) resolved ON true
      WHERE t.inventory_present = false AND t.prev1 = false AND t.prev2 IS DISTINCT FROM false
      ON CONFLICT (second_event_id) DO NOTHING
    SQL

    if binds.any?
      ActiveRecord::Base.connection.exec_query(sql, "AlertGenerator", binds)
    else
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
