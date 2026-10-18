module Paginatable
  extend ActiveSupport::Concern

  PER_PAGE = 50

  def paginate(scope)
    page = params[:page].to_i.clamp(1..)
    # Every caller orders by a non-unique column (event_time, triggered_at) - append
    # the primary key as a tiebreak so ties don't repeat or skip rows across pages.
    scope.order(scope.klass.primary_key => :desc)
         .limit(PER_PAGE)
         .offset((page - 1) * PER_PAGE)
  end
end
