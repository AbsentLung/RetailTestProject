import { Controller } from "@hotwired/stimulus";
class live_search_controller_default extends Controller {
  static targets = ["results", "field"];
  timeout = null;
  apply() {
    if (this.timeout) window.clearTimeout(this.timeout);
    this.timeout = window.setTimeout(() => this.search(), 300);
  }
  async search() {
    const url = new URL(window.location.href);
    this.fieldTargets.forEach((field) => {
      if (field.value) url.searchParams.set(field.name, field.value);
      else url.searchParams.delete(field.name);
    });
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
