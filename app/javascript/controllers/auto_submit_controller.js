import { Controller } from "@hotwired/stimulus"

// GET obrazec: ob vnosu z zakasnitvijo, ob spremembi selecta/datuma takoj.
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 },
    minLength: { type: Number, default: 0 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  debouncedSubmitIfLongEnough(event) {
    const value = event?.target?.value?.trim() || ""
    const minimum = this.minLengthValue || 0
    if (value.length > 0 && value.length < minimum) return

    this.debouncedSubmit()
  }

  submitImmediate() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  // Obstoječi klici (npr. iskalniki)
  submit() {
    this.debouncedSubmit()
  }
}
