require "test_helper"

class KeysetPageTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(name: "Keyset Product", brand: Brand.create!(name: "Keyset Brand"))
    @store = Store.create!(address: "1 Keyset Ave")
  end

  def create_event(time)
    TrackingEvent.create!(product: @product, store: @store, event_time: time, inventory_present: true)
  end

  test "default page returns the most recent rows, newest first" do
    create_event(3.days.ago)
    mid = create_event(2.days.ago)
    newest = create_event(1.day.ago)

    page = KeysetPage.new(TrackingEvent.all, column: :event_time, limit: 2)

    assert_equal [newest, mid], page.rows
  end

  test "next_cursor advances to the next batch, prev_cursor returns to this one" do
    events = (1..5).map { |n| create_event(n.days.ago) }

    first_page = KeysetPage.new(TrackingEvent.all, column: :event_time, limit: 2)
    assert_equal events.first(2), first_page.rows
    assert_not_nil first_page.next_cursor
    assert_nil first_page.prev_cursor, "the first page has nothing before it"

    second_page = KeysetPage.new(TrackingEvent.all, column: :event_time, after: first_page.next_cursor, limit: 2)
    assert_equal events[2, 2], second_page.rows
    assert_not_nil second_page.prev_cursor

    back_to_first = KeysetPage.new(TrackingEvent.all, column: :event_time, before: second_page.prev_cursor, limit: 2)
    assert_equal first_page.rows, back_to_first.rows
  end

  test "the last page has no next_cursor" do
    create_event(2.days.ago)
    create_event(1.day.ago)

    page = KeysetPage.new(TrackingEvent.all, column: :event_time, limit: 50)
    assert_nil page.next_cursor
  end

  test "rows sharing the exact same timestamp are still ordered consistently via the id tiebreak" do
    time = 1.day.ago
    older_id = create_event(time)
    newer_id = create_event(time)

    page = KeysetPage.new(TrackingEvent.all, column: :event_time, limit: 1)
    assert_equal [newer_id], page.rows, "same timestamp - higher id sorts first, matching ORDER BY event_time DESC, id DESC"

    next_page = KeysetPage.new(TrackingEvent.all, column: :event_time, after: page.next_cursor, limit: 1)
    assert_equal [older_id], next_page.rows
  end

  test "a malformed cursor token falls back to the first page instead of raising" do
    create_event(2.days.ago)
    create_event(1.day.ago)

    page = KeysetPage.new(TrackingEvent.all, column: :event_time, after: "not-a-real-token", limit: 50)
    assert_equal 2, page.rows.size
  end

  test "an empty scope has no rows and no cursors" do
    page = KeysetPage.new(TrackingEvent.none, column: :event_time, limit: 50)
    assert page.empty?
    assert_nil page.next_cursor
    assert_nil page.prev_cursor
  end

  def count_queries
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { count += 1 }
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # next_cursor/prev_cursor used to run a separate EXISTS query each, every
  # request, regardless of whether a cursor was even present. The limit+1
  # trick (fetch one extra row, check whether it came back) answers "is
  # there more in the direction just queried" for free, so a cursor-less
  # first page needs no extra query at all, and a cursor-set page needs
  # at most one (for the direction the fetch itself didn't just check).
  test "a cursor-less first page runs no extra queries beyond the one fetch" do
    (1..3).each { |n| create_event(n.days.ago) }

    queries = count_queries do
      page = KeysetPage.new(TrackingEvent.all, column: :event_time, limit: 2)
      page.next_cursor
      page.prev_cursor
    end
    assert_equal 1, queries, "the fetch itself, and nothing else - no EXISTS query for next or prev"
  end

  test "a cursor-set page runs at most one extra query" do
    events = (1..5).map { |n| create_event(n.days.ago) }
    first_page = KeysetPage.new(TrackingEvent.all, column: :event_time, limit: 2)

    queries = count_queries do
      page = KeysetPage.new(TrackingEvent.all, column: :event_time, limit: 2, after: first_page.next_cursor)
      page.next_cursor
      page.prev_cursor
    end
    assert_equal 2, queries, "the fetch, plus one EXISTS query for prev_cursor (next_cursor is free off the forward fetch)"
  end

  # Alerts' sort-by-brand/product/store and sort-by-status use a joined
  # column and a computed boolean, respectively - neither is a plain
  # attribute KeysetPage's default `row.public_send(column)` extractor can
  # read, so each needs its own `value:` proc and (for the joined case) a
  # qualified id_column to stay unambiguous. Verified against real data via
  # `bin/rails runner`, then committed here as a regression test rather
  # than left as a one-off script.
  def make_alert(brand:, store:, triggered_at:, resolved_at: nil)
    product = Product.create!(name: "Product #{SecureRandom.hex(4)}", brand: brand)
    first = TrackingEvent.create!(product: product, store: store, event_time: triggered_at - 1.hour, inventory_present: false)
    second = TrackingEvent.create!(product: product, store: store, event_time: triggered_at, inventory_present: false)
    Alert.create!(brand: brand, product: product, store: store, first_event: first, second_event: second,
      triggered_at: triggered_at, resolved_at: resolved_at)
  end

  test "sorting by a joined column (brand name) crosses a page boundary in order" do
    store = Store.create!(address: "1 Joined Sort Ave")
    brand_a = Brand.create!(name: "AAA Brand")
    brand_m = Brand.create!(name: "MMM Brand")
    brand_z = Brand.create!(name: "ZZZ Brand")
    alert_a = make_alert(brand: brand_a, store: store, triggered_at: 3.days.ago)
    alert_m = make_alert(brand: brand_m, store: store, triggered_at: 2.days.ago)
    alert_z = make_alert(brand: brand_z, store: store, triggered_at: 1.day.ago)

    scope = Alert.eager_load(:brand)
    column = "brands.name"
    id_column = "alerts.id"
    value = ->(a) { a.brand.name }

    first_page = KeysetPage.new(scope, column: column, id_column: id_column, direction: :asc, value: value, limit: 2)
    assert_equal [alert_a, alert_m], first_page.rows
    assert_not_nil first_page.next_cursor

    second_page = KeysetPage.new(scope, column: column, id_column: id_column, direction: :asc, value: value,
      after: first_page.next_cursor, limit: 2)
    assert_equal [alert_z], second_page.rows
    assert_nil second_page.next_cursor
  end

  test "sorting by the computed status boolean crosses the open/resolved boundary in order" do
    brand = Brand.create!(name: "Status Sort Brand")
    store = Store.create!(address: "1 Status Sort Ave")
    open_a = make_alert(brand: brand, store: store, triggered_at: 4.days.ago)
    open_b = make_alert(brand: brand, store: store, triggered_at: 3.days.ago)
    resolved_a = make_alert(brand: brand, store: store, triggered_at: 2.days.ago, resolved_at: 1.day.ago)
    resolved_b = make_alert(brand: brand, store: store, triggered_at: 1.day.ago, resolved_at: 12.hours.ago)

    scope = Alert.all
    column = "(alerts.resolved_at IS NOT NULL)"
    id_column = "alerts.id"
    value = ->(a) { a.resolved_at.present? }

    # Ascending: false (open) sorts before true (resolved) - open alerts
    # should fill every page before a resolved one ever appears.
    first_page = KeysetPage.new(scope, column: column, id_column: id_column, direction: :asc, value: value, limit: 2)
    assert_equal [open_a, open_b].sort_by(&:id), first_page.rows.sort_by(&:id)
    assert first_page.rows.none? { |a| a.resolved_at.present? }

    second_page = KeysetPage.new(scope, column: column, id_column: id_column, direction: :asc, value: value,
      after: first_page.next_cursor, limit: 2)
    assert_equal [resolved_a, resolved_b].sort_by(&:id), second_page.rows.sort_by(&:id)
    assert second_page.rows.all? { |a| a.resolved_at.present? }
    assert_nil second_page.next_cursor
  end
end
