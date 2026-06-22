import { Controller } from "@hotwired/stimulus"

const DISMISS_AFTER_MS = 5000

export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), DISMISS_AFTER_MS)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.remove()
  }
}
