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
  currentFetch: AbortController | null = null

  connect() {
    window.addEventListener("popstate", this.onPopState)
  }

  disconnect() {
    window.removeEventListener("popstate", this.onPopState)
  }

  // An arrow-function property, not a method, so `this` stays bound
  // without a separate .bind() call - needed since this is passed
  // directly to add/removeEventListener as a reference. Swaps in whatever
  // the restored URL actually shows; doesn't push a new history entry,
  // since we're responding to one the browser already navigated to.
  onPopState = () => {
    this.swap(window.location.href, { push: false })
  }

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

  async swap(url: string, { push = true }: { push?: boolean } = {}): Promise<boolean> {
    // Cancel whatever's still in flight before starting a new one - without
    // this, two quick sort/search triggers race, and whichever response
    // happens to arrive last wins even if it isn't the last one requested.
    this.currentFetch?.abort()
    const controller = new AbortController()
    this.currentFetch = controller

    let html
    try {
      // response.text() is in the same try as the fetch itself, not after
      // it - an abort can land mid-body-read just as easily as before the
      // response even arrives, and either way it should be caught here
      // rather than escape as an unhandled rejection (search() calls swap()
      // without awaiting it, so nothing outside this method would catch it).
      const response = await fetch(url, { headers: { Accept: "text/html" }, signal: controller.signal })
      if (!response.ok) return false
      html = await response.text()
    } catch (error) {
      // Being superseded by a newer swap() isn't a failure - don't let
      // sort() treat it as one and fall back to a real navigation.
      if (error instanceof DOMException && error.name === "AbortError") return true
      return false // offline/network failure
    }

    const doc = new DOMParser().parseFromString(html, "text/html")
    const newResults = doc.querySelector('[data-live-search-target="results"]')
    if (!newResults) return false // nothing to show - don't push a URL for a swap that didn't happen
    this.resultsTarget.replaceWith(document.importNode(newResults, true))

    if (push) history.pushState({}, "", url)
    return true
  }
}
