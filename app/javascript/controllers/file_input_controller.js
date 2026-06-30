import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name"]
  static values = { selected: String }

  showName(event) {
    const file = event.target.files[0]
    if (!file || !this.hasNameTarget) return

    const template = this.selectedValue || "Izbrano: %{filename}"
    this.nameTarget.textContent = template.replace("%{filename}", file.name)
    this.nameTarget.classList.remove("hidden")
  }
}
