class BrandsController < ApplicationController
  def index
    @brands = paginate(Brand.all.order(:name))
    @product_counts = Product.group(:brand_id).count
  end

  def show
    @brand = Brand.find(params[:id])
    @event_counts = TrackingEvent.joins(:product).where(products: { brand_id: @brand.id }).group(:product_id).count
    @open_alerts_count = @brand.alerts.where(resolved_at: nil).count
    @alerts = @brand.alerts.includes(:product, :store).order(triggered_at: :desc).limit(10)
  end
end
