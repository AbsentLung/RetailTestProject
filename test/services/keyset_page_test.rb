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
end
