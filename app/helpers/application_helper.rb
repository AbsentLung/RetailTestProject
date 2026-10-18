module ApplicationHelper
  def pagination_links(collection)
    page = params[:page].to_i.clamp(1..)
    links = []
    links << link_to("&laquo; Previous".html_safe, url_for(page: page - 1)) if page > 1
    # A short last page (or the only page) means there's nothing after it -
    # only a full page leaves open the possibility of a next one.
    links << link_to("Next &raquo;".html_safe, url_for(page: page + 1)) if collection.size == Paginatable::PER_PAGE
    safe_join(links, " | ")
  end
end
