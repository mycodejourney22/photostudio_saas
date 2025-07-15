import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="features"
export default class extends Controller {
  static targets = ["list", "template"]

  connect() {
  }

  add() {
    const clone = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(clone)
  }

  remove(event) {
    event.target.closest(".feature-item").remove()
  }
}
