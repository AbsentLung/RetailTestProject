import { Controller } from "@hotwired/stimulus"

// Filters update as the dropdowns change, with no page reload - but the URL
// still ends up exactly where a real navigation to the same filters would
// land, via history.pushState, so reload/share/back-button all still work.
export default class extends Controller {
  static targets = ["results", "exportLink"]

  async apply(event) {
    const form = event.target.form
    const params = new URLSearchParams(new FormData(form))
    for (const [key, value] of [...params.entries()]) {
      if (value === "") params.delete(key)
    }
    const query = params.toString()
    const url = query ? `${form.action}?${query}` : form.action

    let response
    try {
      response = await fetch(url, { headers: { Accept: "text/html" } })
    } catch {
      window.location.assign(url) // offline/network failure - fall back to a real navigation
      return
    }
    if (!response.ok) {
      window.location.assign(url)
      return
    }

    const doc = new DOMParser().parseFromString(await response.text(), "text/html")

    const newResults = doc.querySelector('[data-live-filter-target="results"]')
    if (newResults) this.resultsTarget.replaceWith(document.importNode(newResults, true))

    if (this.hasExportLinkTarget) {
      const newExportLink = doc.querySelector('[data-live-filter-target="exportLink"]')
      if (newExportLink) this.exportLinkTarget.replaceWith(document.importNode(newExportLink, true))
    }

    history.pushState({}, "", url)
  }
}
