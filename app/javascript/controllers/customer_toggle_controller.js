// app/javascript/controllers/customer_toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["existingCustomer", "newCustomer", "radio"]

  connect() {
    this.toggleSections()
  }

  toggle() {
    this.toggleSections()
  }

  toggleSections() {
    const selected = this.radioTargets.find(radio => radio.checked)?.value

    if (selected === "existing") {
      this.existingCustomerTarget.style.display = "block"
      this.newCustomerTarget.style.display = "none"
    } else {
      this.existingCustomerTarget.style.display = "none"
      this.newCustomerTarget.style.display = "block"
    }
  }
}
