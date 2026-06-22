import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "tabla-dark-mode"

export default class extends Controller {
  connect() {
    this.applySavedPreference()
  }

  toggle() {
    const isDark = document.documentElement.classList.toggle("dark")
    localStorage.setItem(STORAGE_KEY, isDark ? "true" : "false")
  }

  applySavedPreference() {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved === "true") {
      document.documentElement.classList.add("dark")
    } else if (saved === "false") {
      document.documentElement.classList.remove("dark")
    }
  }
}
