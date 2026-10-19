import { Controller } from "@hotwired/stimulus"

// Debounced live search: fetches the current page with an updated ?q=
// and swaps in just the results, no page reload and no submit button -
// typing keeps focus in the search box the whole time, which a full
// navigation per keystroke would break. The same fetch-and-replace
// approach as the pre-React alerts filter; a single text field doesn't
// need React's state management the way alerts' filters+sort+cursor did.
export default class extends Controller {
  static targets = ["results"]
  declare readonly resultsTarget: HTMLElement

  timeout: number | null = null

  apply(event: Event) {
    const value = (event.target as HTMLInputElement).value
    if (this.timeout) window.clearTimeout(this.timeout)
    this.timeout = window.setTimeout(() => this.search(value), 300)
  }

  async search(query: string) {
    const url = new URL(window.location.href)
    if (query) url.searchParams.set("q", query)
    else url.searchParams.delete("q")
    url.searchParams.delete("page") // a new search starts over at page 1

    let response
    try {
      response = await fetch(url.toString(), { headers: { Accept: "text/html" } })
    } catch {
      return // offline/network failure - the field still works via a real submit on Enter
    }
    if (!response.ok) return

    const doc = new DOMParser().parseFromString(await response.text(), "text/html")
    const newResults = doc.querySelector('[data-live-search-target="results"]')
    if (newResults) this.resultsTarget.replaceWith(document.importNode(newResults, true))

    history.pushState({}, "", url.toString())
  }
}
