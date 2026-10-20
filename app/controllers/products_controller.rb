class ProductsController < ApplicationController
  # "events" needs a join+group+order combined query (Option 1 in
  # DESIGN_PROPOSAL_FINAL.md's "Sorting by a computed count" section) - the
  # usual display path runs TrackingEvent.group(:product_id).count as a
  # second query instead, since that's cheaper when nothing needs the count
  # to be orderable.
  SORTS = {
    "name" => { order: "products.name", direction: :asc },
    "brand" => { order: "brands.name", direction: :asc },
    "events" => { order: "event_count", direction: :desc },
  }.freeze
  DEFAULT_SORT = "name"

  # Tracking events on a product's show page - a separate sort/filter
  # namespace (event_sort/event_direction, not sort/direction) so it can't
  # collide with a future sort on the product itself.
  EVENT_SORTS = {
    "event_time" => { column: "tracking_events.event_time", id_column: "tracking_events.id", direction: :desc, value: ->(e) { e.event_time } },
    "inventory_present" => { column: "tracking_events.inventory_present", id_column: "tracking_events.id", direction: :asc, value: ->(e) { e.inventory_present } },
    "store" => { column: "stores.address", id_column: "tracking_events.id", direction: :asc, value: ->(e) { e.store.address } },
  }.freeze
  EVENT_DEFAULT_SORT = "event_time"

  helper_method :sort_url, :event_sort_url

  def index
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @direction = %w[asc desc].include?(params[:direction]) ? params[:direction].to_sym : SORTS.fetch(@sort)[:direction]
    @q = params[:q].presence
    @brand_q = params[:brand_q].presence

    scope = case @sort
    when "brand" then Product.includes(:brand).left_joins(:brand)
    when "events" then Product.includes(:brand).left_joins(:tracking_events)
                               .select("products.*, COUNT(tracking_events.id) AS event_count")
                               .group("products.id")
    else Product.includes(:brand)
    end
    # Bound, not interpolated - sanitize_sql_like escapes %/_ so a literal
    # "%" in either term is searched for literally, not as a wildcard. See
    # DESIGN_PROPOSAL_FINAL.md's Search section.
    scope = scope.where("products.name ILIKE ?", "%#{Product.sanitize_sql_like(@q)}%") if @q
    if @brand_q
      scope = scope.left_joins(:brand) unless @sort == "brand"
      scope = scope.where("brands.name ILIKE ?", "%#{Product.sanitize_sql_like(@brand_q)}%")
    end

    @products = paginate(scope.reorder(Arel.sql(SORTS.fetch(@sort)[:order]) => @direction))
    @event_counts = if @sort == "events"
      @products.index_by(&:id).transform_values { |p| p.event_count.to_i }
    else
      TrackingEvent.group(:product_id).count
    end
  end

  def show
    @product = Product.find(params[:id])

    events_scope = filter_events(@product.tracking_events.eager_load(:store))
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
    @store_id = params[:store_id].presence
    # options_for_select wants [label, value] pairs, not [value, label] -
    # plucking id first silently swapped them (caught by a controller test).
    @stores_for_filter = @product.tracking_events.joins(:store).distinct.order("stores.address").pluck("stores.address", "stores.id")

    @latest_price = @product.price_checks.order(event_time: :desc).first
    @price_history = @product.price_checks.order(event_time: :desc).limit(10)
  end

  private

  def filter_events(scope)
    scope = scope.where(inventory_present: true) if params[:inventory_present] == "yes"
    scope = scope.where(inventory_present: false) if params[:inventory_present] == "no"
    scope = scope.where(store_id: params[:store_id]) if params[:store_id].present?
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
    products_path(request.query_parameters.except("page", "sort", "direction").merge(sort: key, direction: direction))
  end

  def event_sort_url(key)
    config = EVENT_SORTS.fetch(key)
    direction = @event_sort == key ? (@event_direction == :asc ? "desc" : "asc") : config[:direction].to_s
    # request.query_parameters is a HashWithIndifferentAccess, which
    # normalizes a merged-in :anchor to a String key - and Rails' URL
    # generation only extracts a literal Symbol :anchor as the fragment, so
    # it would fall through as an ordinary query param. Appending the
    # fragment to the string directly sidesteps that.
    "#{product_path(@product, request.query_parameters.except("before", "after", "event_sort", "event_direction").merge(event_sort: key, event_direction: direction))}#tracking-events"
  end
end
