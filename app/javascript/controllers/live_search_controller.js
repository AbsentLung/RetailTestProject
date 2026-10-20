import { Controller } from "@hotwired/stimulus";
class live_search_controller_default extends Controller {
  static targets = ["results", "field"];
  timeout = null;
  currentFetch = null;
  connect() {
    window.addEventListener("popstate", this.onPopState);
  }
  disconnect() {
    window.removeEventListener("popstate", this.onPopState);
  }
  // An arrow-function property, not a method, so `this` stays bound
  // without a separate .bind() call - needed since this is passed
  // directly to add/removeEventListener as a reference. Swaps in whatever
  // the restored URL actually shows; doesn't push a new history entry,
  // since we're responding to one the browser already navigated to.
  onPopState = () => {
    this.swap(window.location.href, { push: false });
  };
  apply() {
    if (this.timeout) window.clearTimeout(this.timeout);
    this.timeout = window.setTimeout(() => this.search(), 300);
  }
  search() {
    const url = new URL(window.location.href);
    this.fieldTargets.forEach((field) => {
      if (field.value) url.searchParams.set(field.name, field.value);
      else url.searchParams.delete(field.name);
    });
    url.searchParams.delete("page");
    this.swap(url.toString());
  }
  // A sort-header click already carries a complete, correct URL (built
  // server-side by sort_url/event_sort_url) - just fetch it and swap, no
  // need to merge field values the way search() does. Falls back to a
  // real navigation if the fetch itself fails, since a link only gets
  // one chance (no Enter-key retry the way a search field has).
  async sort(event) {
    event.preventDefault();
    const link = event.currentTarget;
    const swapped = await this.swap(link.href);
    if (!swapped) window.location.href = link.href;
  }
  async swap(url, { push = true } = {}) {
    this.currentFetch?.abort();
    const controller = new AbortController();
    this.currentFetch = controller;
    let html;
    try {
      const response = await fetch(url, { headers: { Accept: "text/html" }, signal: controller.signal });
      if (!response.ok) return false;
      html = await response.text();
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") return true;
      return false;
    }
    const doc = new DOMParser().parseFromString(html, "text/html");
    const newResults = doc.querySelector('[data-live-search-target="results"]');
    if (!newResults) return false;
    this.resultsTarget.replaceWith(document.importNode(newResults, true));
    if (push) history.pushState({}, "", url);
    return true;
  }
}
export {
  live_search_controller_default as default
};
