import { Controller } from "@hotwired/stimulus"

// Submits its form whenever a field inside it changes - for the tracking-
// event filters, which stay on plain GET navigation (no React here; see
// DESIGN_PROPOSAL_FINAL.md's Pattern choices for why React is scoped to
// just the alerts filter UI). The form's own submit button stays in the
// DOM as the no-JS fallback.
//
// Builds the GET URL by hand instead of calling form.requestSubmit():
// browsers are inconsistent about keeping a URL fragment (the form's
// action is "/products/1#tracking-events", there to land the reload back
// on the table instead of the top of the page) through a native GET form
// submission - Chrome drops it. Serializing the fields ourselves keeps
// the fragment under our control either way.
export default class extends Controller {
  submit() {
    const form = this.element.closest("form")
    if (!form) return

    const [path, fragment] = form.action.split("#")
    const params = new URLSearchParams()
    for (const [key, value] of new FormData(form).entries()) {
      params.append(key, String(value))
    }

    const query = params.toString()
    const url = query ? `${path}?${query}` : path
    window.location.assign(fragment ? `${url}#${fragment}` : url)
  }
}
