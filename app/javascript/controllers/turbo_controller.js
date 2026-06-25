import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    event.preventDefault()
    const modalFrame = document.getElementById("modal")
    if (modalFrame) modalFrame.innerHTML = ""
  }
}
