import { Controller } from "@hotwired/stimulus"

// Prikaz PDF predogleda; na namizju iframe, ob težavah prikaže fallback.
export default class extends Controller {
  static targets = ["iframe", "fallback"]

  connect() {
    this.timeout = window.setTimeout(() => this.showFallback(), 10_000)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
  }

  loaded() {
    window.clearTimeout(this.timeout)
  }

  showFallback() {
    if (!this.hasFallbackTarget) return

    this.fallbackTarget.classList.remove("hidden")
  }
}
