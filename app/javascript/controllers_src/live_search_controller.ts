import { Controller } from "@hotwired/stimulus"

// Debounced live search plus no-reload sorting, sharing one fetch-and-
// swap mechanism: fetch a URL, swap in just the results, push the new
// URL - no page reload and no submit button, so typing keeps focus in
// the search box and clicking a sort header doesn't reset scroll
// position or re-flash the rest of the page the way a real navigation
// does. Supports more than one independent search field (e.g. products
// searching by name and by brand) - each search reads every field's
// current value, not just the one that just changed, so they combine
// correctly. The same fetch-and-replace approach as the pre-React
// alerts filter; plain text fields and links don't need React's state
// management the way alerts' filters+sort+cursor did.
export default class extends Controller {
  static targets = ["results", "field"]
  declare readonly resultsTarget: HTMLElement
  declare readonly fieldTargets: HTMLInputElement[]

  timeout: number | null = null

  apply() {
    if (this.timeout) window.clearTimeout(this.timeout)
    this.timeout = window.setTimeout(() => this.search(), 300)
  }

  search() {
    const url = new URL(window.location.href)
    this.fieldTargets.forEach((field) => {
      if (field.value) url.searchParams.set(field.name, field.value)
      else url.searchParams.delete(field.name)
    })
    url.searchParams.delete("page") // a new search starts over at page 1
    this.swap(url.toString())
  }

  // A sort-header click already carries a complete, correct URL (built
  // server-side by sort_url/event_sort_url) - just fetch it and swap, no
  // need to merge field values the way search() does. Falls back to a
  // real navigation if the fetch itself fails, since a link only gets
  // one chance (no Enter-key retry the way a search field has).
  async sort(event: Event) {
    event.preventDefault()
    const link = event.currentTarget as HTMLAnchorElement
    const swapped = await this.swap(link.href)
    if (!swapped) window.location.href = link.href
  }

  async swap(url: string): Promise<boolean> {
    let response
    try {
      response = await fetch(url, { headers: { Accept: "text/html" } })
    } catch {
      return false // offline/network failure
    }
    if (!response.ok) return false

    const doc = new DOMParser().parseFromString(await response.text(), "text/html")
    const newResults = doc.querySelector('[data-live-search-target="results"]')
    if (newResults) this.resultsTarget.replaceWith(document.importNode(newResults, true))

    history.pushState({}, "", url)
    return true
  }
}
