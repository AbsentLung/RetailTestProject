module Paginatable
  extend ActiveSupport::Concern

  PER_PAGE = 50

  def paginate(scope)
    page = params[:page].to_i.clamp(1..)
    scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE)
  end
end
