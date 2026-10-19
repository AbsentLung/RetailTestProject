class BrandsController < ApplicationController
  SORTS = {
    "name" => { order: "brands.name", direction: :asc },
    "products" => { order: "product_count", direction: :desc },
  }.freeze
  DEFAULT_SORT = "name"

  helper_method :sort_url

  def index
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @direction = %w[asc desc].include?(params[:direction]) ? params[:direction].to_sym : SORTS.fetch(@sort)[:direction]

    scope = if @sort == "products"
      Brand.left_joins(:products).select("brands.*, COUNT(products.id) AS product_count").group("brands.id")
    else
      Brand.all
    end

    @brands = paginate(scope.reorder(Arel.sql(SORTS.fetch(@sort)[:order]) => @direction))
    @product_counts = if @sort == "products"
      @brands.index_by(&:id).transform_values { |b| b.product_count.to_i }
    else
      Product.group(:brand_id).count
    end
  end

  def show
    @brand = Brand.find(params[:id])
    @event_counts = TrackingEvent.joins(:product).where(products: { brand_id: @brand.id }).group(:product_id).count
    @open_alerts_count = @brand.alerts.where(resolved_at: nil).count
    @alerts = @brand.alerts.includes(:product, :store).order(triggered_at: :desc).limit(10)
  end

  private

  def sort_url(key)
    config = SORTS.fetch(key)
    direction = @sort == key ? (@direction == :asc ? "desc" : "asc") : config[:direction].to_s
    brands_path(request.query_parameters.except("page", "sort", "direction").merge(sort: key, direction: direction))
  end
end
