class ProductsController < ApplicationController
  def index
    @products = Product.includes(:brand)
    @event_counts = TrackingEvent.group(:product_id).count
  end

  def show
    @product = Product.find(params[:id])
    @events = paginate(@product.tracking_events.includes(:store).order(event_time: :desc))
    @latest_price = @product.price_checks.order(event_time: :desc).first
    @price_history = @product.price_checks.order(event_time: :desc).limit(10)
  end
end
