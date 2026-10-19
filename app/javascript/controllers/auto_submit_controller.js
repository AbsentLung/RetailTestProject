import { Controller } from "@hotwired/stimulus";
class auto_submit_controller_default extends Controller {
  submit() {
    const form = this.element.closest("form");
    if (!form) return;
    const [path, fragment] = form.action.split("#");
    const params = new URLSearchParams();
    for (const [key, value] of new FormData(form).entries()) {
      params.append(key, String(value));
    }
    const query = params.toString();
    const url = query ? `${path}?${query}` : path;
    window.location.assign(fragment ? `${url}#${fragment}` : url);
  }
}
export {
  auto_submit_controller_default as default
};
