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
    @rows = fetch_rows(after, before)
  end

  def empty?
    rows.empty?
  end

  def next_cursor
    return nil if rows.empty?
    last = rows.last
    KeysetCursor.encode(@value.call(last), last.id) if more?(last, forward: true)
  end

  def prev_cursor
    return nil if rows.empty?
    first = rows.first
    KeysetCursor.encode(@value.call(first), first.id) if more?(first, forward: false)
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

  def fetch_rows(after, before)
    if before.present? && (cursor = safe_decode(before))
      value, id = cursor
      @scope.where("(#{@column}, #{@id_column}) #{backward_operator} (?, ?)", value, id)
            .reorder(Arel.sql(@column) => backward_direction, Arel.sql(@id_column) => backward_direction)
            .limit(@limit)
            .to_a
            .reverse
    elsif after.present? && (cursor = safe_decode(after))
      value, id = cursor
      @scope.where("(#{@column}, #{@id_column}) #{forward_operator} (?, ?)", value, id)
            .reorder(Arel.sql(@column) => @direction, Arel.sql(@id_column) => @direction)
            .limit(@limit)
            .to_a
    else
      @scope.reorder(Arel.sql(@column) => @direction, Arel.sql(@id_column) => @direction).limit(@limit).to_a
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
