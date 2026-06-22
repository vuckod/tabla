import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container", "item"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.content.cloneNode(true)
    const timestamp = Date.now().toString()

    content.querySelectorAll("[name]").forEach((element) => {
      element.name = element.name.replace(/NEW_RECORD/g, timestamp)
      if (element.id) {
        element.id = element.id.replace(/NEW_RECORD/g, timestamp)
      }
    })

    this.containerTarget.appendChild(content)
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest("[data-nested-form-target='item']")
    if (!item) return

    const destroyField = item.querySelector("input[name*='[_destroy]']")
    if (destroyField) {
      destroyField.value = "1"
      item.classList.add("hidden")
    } else {
      item.remove()
    }
  }
}
