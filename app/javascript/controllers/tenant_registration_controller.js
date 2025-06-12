// app/javascript/controllers/tenant_registration_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["subdomain", "preview"]

  connect() {
    this.updatePreview()
  }

  updatePreview() {
    const subdomain = this.subdomainTarget.value || "your-studio"
    const cleanSubdomain = subdomain.toLowerCase().replace(/[^a-z0-9-]/g, '')

    // Update the input with cleaned value
    if (cleanSubdomain !== subdomain) {
      this.subdomainTarget.value = cleanSubdomain
    }

    this.previewTarget.textContent = `${cleanSubdomain}.photostudio.com`
  }
}
