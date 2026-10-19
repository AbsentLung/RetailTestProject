class StoresController < ApplicationController
  SORTS = {
    "address" => { order: "stores.address", direction: :asc },
    "events" => { order: "event_count", direction: :desc },
  }.freeze
  DEFAULT_SORT = "address"

  EVENT_SORTS = {
    "event_time" => { column: "tracking_events.event_time", id_column: "tracking_events.id", direction: :desc, value: ->(e) { e.event_time } },
    "inventory_present" => { column: "tracking_events.inventory_present", id_column: "tracking_events.id", direction: :asc, value: ->(e) { e.inventory_present } },
    "product" => { column: "products.name", id_column: "tracking_events.id", direction: :asc, value: ->(e) { e.product.name } },
  }.freeze
  EVENT_DEFAULT_SORT = "event_time"

  helper_method :sort_url, :event_sort_url

  def index
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @direction = %w[asc desc].include?(params[:direction]) ? params[:direction].to_sym : SORTS.fetch(@sort)[:direction]

    scope = if @sort == "events"
      Store.left_joins(:tracking_events).select("stores.*, COUNT(tracking_events.id) AS event_count").group("stores.id")
    else
      Store.all
    end

    @stores = paginate(scope.reorder(Arel.sql(SORTS.fetch(@sort)[:order]) => @direction))
    @event_counts = if @sort == "events"
      @stores.index_by(&:id).transform_values { |s| s.event_count.to_i }
    else
      TrackingEvent.group(:store_id).count
    end
  end

  def show
    @store = Store.find(params[:id])

    events_scope = filter_events(@store.tracking_events.eager_load(product: :brand))
    @event_sort = EVENT_SORTS.key?(params[:event_sort]) ? params[:event_sort] : EVENT_DEFAULT_SORT
    @event_direction = %w[asc desc].include?(params[:event_direction]) ? params[:event_direction].to_sym : EVENT_SORTS.fetch(@event_sort)[:direction]
    sort_config = EVENT_SORTS.fetch(@event_sort)

    @events_page = KeysetPage.new(events_scope, column: sort_config[:column], id_column: sort_config[:id_column],
                                  direction: @event_direction, value: sort_config[:value],
                                  after: params[:after], before: params[:before])
    @events = @events_page.rows

    @inventory_present = params[:inventory_present] if %w[yes no].include?(params[:inventory_present])
    @from = params[:from].presence
    @to = params[:to].presence
    @product_id = params[:product_id].presence
    # options_for_select wants [label, value] pairs, not [value, label] -
    # plucking id first silently swapped them (caught by a controller test).
    @products_for_filter = @store.tracking_events.joins(:product).distinct.order("products.name").pluck("products.name", "products.id")

    @price_history = @store.price_checks.includes(:product).order(event_time: :desc).limit(10)
  end

  private

  def filter_events(scope)
    scope = scope.where(inventory_present: true) if params[:inventory_present] == "yes"
    scope = scope.where(inventory_present: false) if params[:inventory_present] == "no"
    scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?
    if (from = parse_date(params[:from]))
      scope = scope.where("tracking_events.event_time >= ?", from.beginning_of_day)
    end
    if (to = parse_date(params[:to]))
      scope = scope.where("tracking_events.event_time <= ?", to.end_of_day)
    end
    scope
  end

  def parse_date(str)
    Date.iso8601(str) if str.present?
  rescue ArgumentError
    nil
  end

  def sort_url(key)
    config = SORTS.fetch(key)
    direction = @sort == key ? (@direction == :asc ? "desc" : "asc") : config[:direction].to_s
    stores_path(request.query_parameters.except("page", "sort", "direction").merge(sort: key, direction: direction))
  end

  def event_sort_url(key)
    config = EVENT_SORTS.fetch(key)
    direction = @event_sort == key ? (@event_direction == :asc ? "desc" : "asc") : config[:direction].to_s
    store_path(@store, request.query_parameters.except("before", "after", "event_sort", "event_direction").merge(event_sort: key, event_direction: direction))
  end
end
