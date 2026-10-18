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
    scope.order(scope.klass.primary_key => :desc)
         .limit(PER_PAGE + 1)
         .offset((page - 1) * PER_PAGE)
  end
end
