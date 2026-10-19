import { Controller } from "@hotwired/stimulus";
const SORT_PARAMS = ["event_sort", "event_direction"];
class auto_submit_controller_default extends Controller {
  submit() {
    const form = this.element.closest("form");
    if (!form) return;
    const [path, fragment] = form.action.split("#");
    const params = new URLSearchParams();
    const current = new URL(window.location.href);
    for (const key of SORT_PARAMS) {
      const value = current.searchParams.get(key);
      if (value) params.set(key, value);
    }
    for (const [key, value] of new FormData(form).entries()) {
      params.set(key, String(value));
    }
    const query = params.toString();
    const url = query ? `${path}?${query}` : path;
    window.location.assign(fragment ? `${url}#${fragment}` : url);
  }
}
export {
  auto_submit_controller_default as default
};
