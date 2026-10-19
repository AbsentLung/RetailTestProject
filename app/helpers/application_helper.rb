module ApplicationHelper
  def pagination_links(collection)
    page = params[:page].to_i.clamp(1..)
    links = []
    # Merging into request.query_parameters (not just {page:}) keeps any
    # active filters (status, brand_id) applied across page changes.
    links << link_to("&laquo; Previous".html_safe, url_for(request.query_parameters.merge(page: page - 1))) if page > 1
    # paginate fetches PER_PAGE + 1 rows precisely so this can tell a full
    # page that's genuinely the last one from a full page with more after it -
    # collection.size == PER_PAGE alone can't make that distinction when the
    # total row count happens to be an exact multiple of PER_PAGE.
    links << link_to("Next &raquo;".html_safe, url_for(request.query_parameters.merge(page: page + 1))) if collection.size > Paginatable::PER_PAGE
    return "".html_safe if links.empty?
    content_tag(:nav, safe_join(links, " "), class: "pagination")
  end

  def nav_link(text, path, section)
    classes = ["nav-link"]
    classes << "active" if params[:controller] == section
    link_to text, path, class: classes.join(" ")
  end

  def alert_status_pill(alert)
    if alert.resolved_at
      content_tag(:span, "Resolved #{alert.resolved_at.strftime('%Y-%m-%d')}", class: "pill pill-resolved")
    else
      content_tag(:span, "Ongoing", class: "pill pill-open")
    end
  end
end
