class StoresController < ApplicationController
  def index
    @stores = paginate(Store.all.order(:address))
    @event_counts = TrackingEvent.group(:store_id).count
  end

  def show
    @store = Store.find(params[:id])
    @events = paginate(@store.tracking_events.includes(product: :brand).order(event_time: :desc))
    @price_history = @store.price_checks.includes(:product).order(event_time: :desc).limit(10)
  end
end
