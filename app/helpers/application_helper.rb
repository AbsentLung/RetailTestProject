module ApplicationHelper
  def pagination_links
    page = params[:page].to_i.clamp(1..)
    links = []
    links << link_to("&laquo; Previous".html_safe, url_for(page: page - 1)) if page > 1
    links << link_to("Next &raquo;".html_safe, url_for(page: page + 1))
    safe_join(links, " | ")
  end
end
