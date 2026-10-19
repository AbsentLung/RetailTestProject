require "csv"

class AlertsController < ApplicationController
  STATUSES = %w[open resolved].freeze

  # Each sort needs its own cursor column, matching the real table/join it
  # reads from. "status" sorts on a computed boolean
  # (resolved_at IS NOT NULL) rather than resolved_at itself, since
  # resolved_at is NULL for every open alert and NULL never satisfies a
  # keyset "<"/">" comparison - a boolean expression is never NULL, so this
  # sidesteps that without a three-column cursor.
  SORTS = {
    "brand" => { column: "brands.name", id_column: "alerts.id", direction: :asc, value: ->(a) { a.brand.name } },
    "product" => { column: "products.name", id_column: "alerts.id", direction: :asc, value: ->(a) { a.product.name } },
    "store" => { column: "stores.address", id_column: "alerts.id", direction: :asc, value: ->(a) { a.store.address } },
    "triggered_at" => { column: "alerts.triggered_at", id_column: "alerts.id", direction: :desc, value: ->(a) { a.triggered_at } },
    "status" => { column: "(alerts.resolved_at IS NOT NULL)", id_column: "alerts.id", direction: :asc, value: ->(a) { a.resolved_at.present? } },
  }.freeze
  DEFAULT_SORT = "triggered_at"

  helper_method :sort_url

  def index
    # eager_load (one LEFT OUTER JOIN), not includes (separate preload
    # queries): sorting/filtering by brand, product, or store name needs
    # those tables in the same query, and every sort option benefits from
    # not needing a second round trip for display either way.
    scope = Alert.eager_load(:brand, :product, :store)
    scope = filter_by_status(scope)
    scope = filter_by_brand(scope)

    @sort = SORTS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @direction = %w[asc desc].include?(params[:direction]) ? params[:direction].to_sym : SORTS.fetch(@sort)[:direction]
    sort_config = SORTS.fetch(@sort)

    @page = KeysetPage.new(scope, column: sort_config[:column], id_column: sort_config[:id_column],
                                  direction: @direction, value: sort_config[:value],
                                  after: params[:after], before: params[:before])
    @alerts = @page.rows
    @status = params[:status] if STATUSES.include?(params[:status])
    @brand_id = params[:brand_id].presence
    @brands = Brand.order(:name)

    respond_to do |format|
      format.html
      # The React filter UI's own data source - same filtered/sorted scope
      # as the HTML view, just serialized instead of rendered. Not a
      # general-purpose API; it exists for this one page's own JS.
      format.json { render json: alerts_json }
      # Exports every alert matching the active filters, not just the current
      # page - a cursor marks a position in the keyset scroll, not a bound on
      # what "the current view" means for an export. Sorted the same way the
      # page currently is, for the same reason - "the current view" again.
      format.csv { send_data alerts_csv(scope, sort_config), filename: "alerts-#{Date.current.iso8601}.csv" }
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

  # The href a column header link points to: toggles direction if it's
  # already the active sort, otherwise switches to that column's own
  # natural first direction (newest-first for a date, A-to-Z for a name).
  # Drops any existing cursor - a cursor is a position under the OLD sort
  # order, meaningless under a new one.
  def sort_url(key)
    config = SORTS.fetch(key)
    direction = if @sort == key
      @direction == :asc ? "desc" : "asc"
    else
      config[:direction].to_s
    end
    alerts_path(request.query_parameters.except("before", "after", "sort", "direction").merge(sort: key, direction: direction))
  end

  def alerts_json
    {
      alerts: @alerts.map { |a|
        {
          id: a.id,
          brand: { id: a.brand.id, name: a.brand.name },
          product: { id: a.product.id, name: a.product.name },
          store: { id: a.store.id, address: a.store.address },
          triggered_at: a.triggered_at.iso8601,
          resolved_at: a.resolved_at&.iso8601,
        }
      },
      brands: @brands.map { |b| { id: b.id, name: b.name } },
      sort: @sort,
      direction: @direction,
      next_cursor: @page.next_cursor,
      prev_cursor: @page.prev_cursor,
    }
  end

  def alerts_csv(scope, sort_config)
    ordered = scope.reorder(Arel.sql(sort_config[:column]) => @direction, Arel.sql(sort_config[:id_column]) => @direction)
    CSV.generate(headers: true) do |csv|
      csv << ["Brand", "Product", "Store", "Triggered At", "Status"]
      ordered.each do |alert|
        csv << [
          csv_safe(alert.brand.name),
          csv_safe(alert.product.name),
          csv_safe(alert.store.address),
          alert.triggered_at.iso8601,
          alert.resolved_at ? "Resolved #{alert.resolved_at.to_date.iso8601}" : "Ongoing",
        ]
      end
    end
  end

  # A cell starting with =, +, -, or @ is run as a formula by whatever
  # spreadsheet app opens this export, not displayed as text. This app's
  # data is fictional, so the real-world risk is low, but every exported
  # value traces back to a brand/product/store name entered at import
  # time - prefixing with a literal quote defuses it either way.
  FORMULA_PREFIXES = %w[= + - @].freeze

  def csv_safe(value)
    FORMULA_PREFIXES.include?(value[0]) ? "'#{value}" : value
  end
end
