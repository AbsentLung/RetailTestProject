# Keyset (cursor) pagination for alerts and tracking events - see
# "Infinite scroll, and why it isn't just a visual choice" in
# DESIGN_PROPOSAL_FINAL.md. Unlike Paginatable (used for the small
# products/stores/brands index pages), cost here doesn't grow with depth
# and results can't skip or repeat rows if the underlying table changes
# between requests.
#
# `scope` must be a relation with no order/limit of its own. `column` is a
# SQL expression to sort and compare by - a plain column (e.g. "event_time")
# or a qualified/computed one (e.g. "brands.name", "resolved_at IS NOT NULL")
# when sorting alerts by brand or status. `id_column` defaults to "id", but
# needs qualifying (e.g. "alerts.id") whenever `column` references a joined
# table, to stay unambiguous. `value` extracts the comparable Ruby value for
# a loaded row when `column` isn't a plain attribute `row.public_send` can
# read directly (e.g. a joined association's name, or a computed boolean).
class KeysetPage
  LIMIT = 50

  attr_reader :rows

  def initialize(scope, column:, after: nil, before: nil, limit: LIMIT, id_column: "id", direction: :desc, value: nil)
    @scope = scope
    @column = column.to_s
    @id_column = id_column.to_s
    @direction = direction
    @value = value || ->(row) { row.public_send(column) }
    @limit = limit
    @before_cursor = before.present? ? safe_decode(before) : nil
    @after_cursor = @before_cursor.nil? && after.present? ? safe_decode(after) : nil
    @rows, @more_in_fetch_direction = fetch_rows
  end

  def empty?
    rows.empty?
  end

  # Fetching limit+1 rows and checking whether the extra one came back (the
  # same trick Paginatable uses) answers "is there more in the direction we
  # just queried" with no extra query - that's enough for next_cursor off
  # an "after" fetch (or the cursor-less first page) and for prev_cursor
  # off a "before" fetch. The opposite direction - "is there a page behind
  # the one we navigated to" - still needs one EXISTS query, but only when
  # a cursor was actually given; the first page never needs it; there's
  # nothing before it.
  def next_cursor
    return nil if rows.empty?
    last = rows.last
    has_more = @before_cursor ? more?(last, forward: true) : @more_in_fetch_direction
    KeysetCursor.encode(@value.call(last), last.id) if has_more
  end

  def prev_cursor
    return nil if rows.empty?
    first = rows.first
    has_more =
      if @after_cursor
        more?(first, forward: false)
      elsif @before_cursor
        @more_in_fetch_direction
      else
        false
      end
    KeysetCursor.encode(@value.call(first), first.id) if has_more
  end

  private

  # "forward" means "continues the scroll in the direction it's already
  # going" - toward older alerts on a DESC-by-date list, or further into
  # the alphabet on an ASC-by-name one. Not always "greater than": that
  # depends on which way @direction already points.
  def forward_operator
    @direction == :desc ? "<" : ">"
  end

  def backward_operator
    @direction == :desc ? ">" : "<"
  end

  def backward_direction
    @direction == :desc ? :asc : :desc
  end

  def fetch_rows
    if @before_cursor
      value, id = @before_cursor
      fetched = @scope.where("(#{@column}, #{@id_column}) #{backward_operator} (?, ?)", value, id)
            .reorder(Arel.sql(@column) => backward_direction, Arel.sql(@id_column) => backward_direction)
            .limit(@limit + 1)
            .to_a
      [fetched.first(@limit).reverse, fetched.size > @limit]
    elsif @after_cursor
      value, id = @after_cursor
      fetched = @scope.where("(#{@column}, #{@id_column}) #{forward_operator} (?, ?)", value, id)
            .reorder(Arel.sql(@column) => @direction, Arel.sql(@id_column) => @direction)
            .limit(@limit + 1)
            .to_a
      [fetched.first(@limit), fetched.size > @limit]
    else
      fetched = @scope.reorder(Arel.sql(@column) => @direction, Arel.sql(@id_column) => @direction).limit(@limit + 1).to_a
      [fetched.first(@limit), fetched.size > @limit]
    end
  end

  def safe_decode(token)
    KeysetCursor.decode(token)
  rescue KeysetCursor::InvalidToken
    nil
  end

  def more?(row, forward:)
    operator = forward ? forward_operator : backward_operator
    @scope.where("(#{@column}, #{@id_column}) #{operator} (?, ?)", @value.call(row), row.id).exists?
  end
end
