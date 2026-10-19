require "csv"

class AlertsController < ApplicationController
  STATUSES = %w[open resolved].freeze

  def index
    scope = Alert.includes(:brand, :product, :store)
    scope = filter_by_status(scope)
    scope = filter_by_brand(scope)

    respond_to do |format|
      format.html do
        @page = KeysetPage.new(scope, column: :triggered_at, after: params[:after], before: params[:before])
        @alerts = @page.rows
        @status = params[:status] if STATUSES.include?(params[:status])
        @brand_id = params[:brand_id].presence
        @brands = Brand.order(:name)
      end
      # Exports every alert matching the active filters, not just the current
      # page - a cursor marks a position in the keyset scroll, not a bound on
      # what "the current view" means for an export.
      format.csv { send_data alerts_csv(scope), filename: "alerts-#{Date.current.iso8601}.csv" }
    end
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

  def alerts_csv(scope)
    CSV.generate(headers: true) do |csv|
      csv << ["Brand", "Product", "Store", "Triggered At", "Status"]
      scope.reorder(triggered_at: :desc, id: :desc).each do |alert|
        csv << [
          alert.brand.name,
          alert.product.name,
          alert.store.address,
          alert.triggered_at.iso8601,
          alert.resolved_at ? "Resolved #{alert.resolved_at.to_date.iso8601}" : "Ongoing",
        ]
      end
    end
  end
end
