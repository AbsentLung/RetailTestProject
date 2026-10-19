class AlertsController < ApplicationController
  STATUSES = %w[open resolved].freeze

  def index
    scope = Alert.includes(:brand, :product, :store)
    scope = filter_by_status(scope)
    scope = filter_by_brand(scope)
    @page = KeysetPage.new(scope, column: :triggered_at, after: params[:after], before: params[:before])
    @alerts = @page.rows
    @status = params[:status] if STATUSES.include?(params[:status])
    @brand_id = params[:brand_id].presence
    @brands = Brand.order(:name)
  end

  def show
    @alert = Alert.includes(:brand, :product, :store, :first_event, :second_event).find(params[:id])
  end

  private

  def filter_by_status(scope)
    case params[:status]
    when "open" then scope.where(resolved_at: nil)
    when "resolved" then scope.where.not(resolved_at: nil)
    else scope
    end
  end

  def filter_by_brand(scope)
    return scope unless params[:brand_id].present?
    scope.where(brand_id: params[:brand_id])
  end
end
