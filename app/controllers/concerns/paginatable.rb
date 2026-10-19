module Paginatable
  extend ActiveSupport::Concern

  PER_PAGE = 50

  def paginate(scope)
    page = params[:page].to_i.clamp(1..)
    # Callers may order by a non-unique column (event_time, triggered_at) - append
    # the primary key as a tiebreak so ties don't repeat or skip rows across pages.
    #
    # Fetches one extra row (PER_PAGE + 1) so pagination_links can tell a full
    # page that's genuinely the last one from a full page with more after it,
    # without a separate COUNT query. Callers render only #first(PER_PAGE).
    #
    # .to_a here, not a bare Relation: Relation#first(n) on an unloaded
    # relation runs its own fresh query (substituting its own LIMIT n and
    # discarding this one's LIMIT PER_PAGE + 1 entirely), and an unloaded
    # Relation#size with a limit set triggers yet another COUNT query -
    # two round trips per page view instead of one. Materializing once here
    # means every later #first/#size call is plain Array#first/Array#size,
    # no further queries.
    scope.order(scope.klass.primary_key => :desc)
         .limit(PER_PAGE + 1)
         .offset((page - 1) * PER_PAGE)
         .to_a
  end
end
