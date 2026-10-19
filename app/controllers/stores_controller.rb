class StoresController < ApplicationController
  def index
    @stores = paginate(Store.all.order(:address))
    @event_counts = TrackingEvent.group(:store_id).count
  end

  def show
    @store = Store.find(params[:id])
    events_scope = @store.tracking_events.includes(product: :brand)
    @events_page = KeysetPage.new(events_scope, column: :event_time, after: params[:after], before: params[:before])
    @events = @events_page.rows
    @price_history = @store.price_checks.includes(:product).order(event_time: :desc).limit(10)
  end
end
