class ProductsController < ApplicationController
  def index
    @products = paginate(Product.includes(:brand).order(:name))
    @event_counts = TrackingEvent.group(:product_id).count
  end

  def show
    @product = Product.find(params[:id])
    events_scope = @product.tracking_events.includes(:store)
    @events_page = KeysetPage.new(events_scope, column: :event_time, after: params[:after], before: params[:before])
    @events = @events_page.rows
    @latest_price = @product.price_checks.order(event_time: :desc).first
    @price_history = @product.price_checks.order(event_time: :desc).limit(10)
  end
end
