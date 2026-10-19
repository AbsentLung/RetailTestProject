module ApplicationHelper
  def pagination_links(collection)
    page = params[:page].to_i.clamp(1..)
    links = []
    links << link_to("&laquo; Previous".html_safe, url_for(page: page - 1)) if page > 1
    # paginate fetches PER_PAGE + 1 rows precisely so this can tell a full
    # page that's genuinely the last one from a full page with more after it -
    # collection.size == PER_PAGE alone can't make that distinction when the
    # total row count happens to be an exact multiple of PER_PAGE.
    links << link_to("Next &raquo;".html_safe, url_for(page: page + 1)) if collection.size > Paginatable::PER_PAGE
    safe_join(links, " | ")
  end
end
