# Keyset (cursor) pagination for alerts and tracking events - see
# "Infinite scroll, and why it isn't just a visual choice" in
# DESIGN_PROPOSAL_FINAL.md. Unlike Paginatable (used for the small
# products/stores/brands index pages), cost here doesn't grow with depth
# and results can't skip or repeat rows if the underlying table changes
# between requests.
#
# `scope` must be a relation with no order/limit of its own - this applies
# both. `column` is the datetime column to sort by (descending); `id` is
# always the tiebreak, so it needs a (column, id) index to stay a single
# ordered scan (see db/migrate/20261018220000_add_keyset_indexes.rb).
class KeysetPage
  LIMIT = 50

  attr_reader :rows

  def initialize(scope, column:, after: nil, before: nil, limit: LIMIT)
    @scope = scope
    @column = column
    @limit = limit
    @rows = fetch_rows(after, before)
  end

  def empty?
    rows.empty?
  end

  def next_cursor
    return nil if rows.empty?
    last = rows.last
    KeysetCursor.encode(last.public_send(@column), last.id) if more_after?(last)
  end

  def prev_cursor
    return nil if rows.empty?
    first = rows.first
    KeysetCursor.encode(first.public_send(@column), first.id) if more_before?(first)
  end

  private

  def fetch_rows(after, before)
    if before.present? && (cursor = safe_decode(before))
      value, id = cursor
      @scope.where("(#{@column}, id) > (?, ?)", value, id)
            .reorder(@column => :asc, id: :asc)
            .limit(@limit)
            .to_a
            .reverse
    elsif after.present? && (cursor = safe_decode(after))
      value, id = cursor
      @scope.where("(#{@column}, id) < (?, ?)", value, id)
            .reorder(@column => :desc, id: :desc)
            .limit(@limit)
            .to_a
    else
      @scope.reorder(@column => :desc, id: :desc).limit(@limit).to_a
    end
  end

  def safe_decode(token)
    KeysetCursor.decode(token)
  rescue KeysetCursor::InvalidToken
    nil
  end

  def more_after?(row)
    @scope.where("(#{@column}, id) < (?, ?)", row.public_send(@column), row.id).exists?
  end

  def more_before?(row)
    @scope.where("(#{@column}, id) > (?, ?)", row.public_send(@column), row.id).exists?
  end
end
