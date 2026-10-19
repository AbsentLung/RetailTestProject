import { Controller } from "@hotwired/stimulus";
class live_search_controller_default extends Controller {
  static targets = ["results"];
  timeout = null;
  apply(event) {
    const value = event.target.value;
    if (this.timeout) window.clearTimeout(this.timeout);
    this.timeout = window.setTimeout(() => this.search(value), 300);
  }
  async search(query) {
    const url = new URL(window.location.href);
    if (query) url.searchParams.set("q", query);
    else url.searchParams.delete("q");
    url.searchParams.delete("page");
    let response;
    try {
      response = await fetch(url.toString(), { headers: { Accept: "text/html" } });
    } catch {
      return;
    }
    if (!response.ok) return;
    const doc = new DOMParser().parseFromString(await response.text(), "text/html");
    const newResults = doc.querySelector('[data-live-search-target="results"]');
    if (newResults) this.resultsTarget.replaceWith(document.importNode(newResults, true));
    history.pushState({}, "", url.toString());
  }
}
export {
  live_search_controller_default as default
};
