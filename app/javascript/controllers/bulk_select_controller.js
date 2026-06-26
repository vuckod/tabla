import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "count", "checkbox", "selectAll"]

  connect() {
    this.updateBar()
  }

  toggle() {
    this.updateBar()
  }

  toggleAll(event) {
    this.visibleCheckboxes().forEach((cb) => { cb.checked = event.target.checked })
    this.updateBar()
  }

  submitCategorize(event) {
    if (!event.target.value) return
    this.element.requestSubmit()
  }

  visibleCheckboxes() {
    return this.checkboxTargets.filter((cb) => cb.offsetParent !== null)
  }

  updateBar() {
    const checked = this.visibleCheckboxes().filter((cb) => cb.checked)
    const label = this.countTarget.dataset.label || "izbranih"
    this.countTarget.textContent = `${checked.length} ${label}`
    this.barTarget.classList.toggle("hidden", checked.length === 0)
    this.barTarget.classList.toggle("flex", checked.length > 0)

    if (this.hasSelectAllTarget) {
      const visible = this.visibleCheckboxes()
      const allChecked = visible.length > 0 && checked.length === visible.length
      this.selectAllTarget.checked = allChecked
      this.selectAllTarget.indeterminate = checked.length > 0 && !allChecked
    }
  }
}
