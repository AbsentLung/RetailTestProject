import { Controller } from "@hotwired/stimulus"

// Debounced live search: fetches the current page with updated query
// params (one per search field, named by the field's own `name` attribute)
// and swaps in just the results - no page reload and no submit button, so
// typing keeps focus in the search box the whole time. Supports more than
// one independent field (e.g. products searching by name and by brand) -
// each search reads every field's current value, not just the one that
// just changed, so they combine correctly. The same fetch-and-replace
// approach as the pre-React alerts filter; plain text fields don't need
// React's state management the way alerts' filters+sort+cursor did.
export default class extends Controller {
  static targets = ["results", "field"]
  declare readonly resultsTarget: HTMLElement
  declare readonly fieldTargets: HTMLInputElement[]

  timeout: number | null = null

  apply() {
    if (this.timeout) window.clearTimeout(this.timeout)
    this.timeout = window.setTimeout(() => this.search(), 300)
  }

  async search() {
    const url = new URL(window.location.href)
    this.fieldTargets.forEach((field) => {
      if (field.value) url.searchParams.set(field.name, field.value)
      else url.searchParams.delete(field.name)
    })
    url.searchParams.delete("page") // a new search starts over at page 1

    let response
    try {
      response = await fetch(url.toString(), { headers: { Accept: "text/html" } })
    } catch {
      return // offline/network failure - the fields still work via a real submit on Enter
    }
    if (!response.ok) return

    const doc = new DOMParser().parseFromString(await response.text(), "text/html")
    const newResults = doc.querySelector('[data-live-search-target="results"]')
    if (newResults) this.resultsTarget.replaceWith(document.importNode(newResults, true))

    history.pushState({}, "", url.toString())
  }
}
