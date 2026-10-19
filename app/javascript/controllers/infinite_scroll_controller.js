import { Controller } from "@hotwired/stimulus"

// Auto-loads further keyset pages as the "Next" link scrolls into view,
// by fetching the exact same URL that link already points to and appending
// what it returns - no JSON API, no new route, just the GET requests the
// link would make anyway. The link itself stays in the DOM and keeps
// working normally for no-JS/keyboard navigation and as a visible fallback
// if a batch load fails - see DESIGN_PROPOSAL_FINAL.md's infinite-scroll
// usability notes.
export default class extends Controller {
  static targets = ["rows"]

  connect() {
    this.observer = new IntersectionObserver(this.handleIntersect.bind(this), { rootMargin: "600px" })
    this.observeCurrentLink()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  observeCurrentLink() {
    this.currentLink = this.element.querySelector("a.next-link")
    if (this.currentLink) this.observer.observe(this.currentLink)
  }

  handleIntersect(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        this.observer.unobserve(entry.target)
        this.loadMore(entry.target.href)
      }
    })
  }

  async loadMore(url) {
    let response
    try {
      response = await fetch(url, { headers: { Accept: "text/html" } })
    } catch {
      return // offline/network failure - the visible link is still there to retry by hand
    }
    if (!response.ok) return

    const doc = new DOMParser().parseFromString(await response.text(), "text/html")
    const scope = doc.querySelector('[data-controller~="infinite-scroll"]')
    if (!scope) return

    const newRows = scope.querySelectorAll('[data-infinite-scroll-target="rows"] > tr')
    newRows.forEach((row) => this.rowsTarget.appendChild(document.importNode(row, true)))

    const newLink = scope.querySelector("a.next-link")
    if (newLink) {
      const imported = document.importNode(newLink, true)
      this.currentLink.replaceWith(imported)
      this.currentLink = imported
      this.observer.observe(imported)
    } else {
      this.currentLink.remove()
    }
  }
}
