// app/javascript/controllers/mobile_navigation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "backdrop"]

  connect() {
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.handleResize)
  }

  disconnect() {
    window.removeEventListener('resize', this.handleResize)
    this.hideBackdrop()
  }

  toggleMenu() {
    const isOpen = !this.menuTarget.classList.contains('-translate-x-full')

    if (isOpen) {
      this.closeMenu()
    } else {
      this.openMenu()
    }
  }

  openMenu() {
    // Show the menu
    this.menuTarget.classList.remove('-translate-x-full')
    this.menuTarget.classList.add('translate-x-0')

    // Show backdrop
    this.showBackdrop()

    // Prevent body scroll
    document.body.classList.add('overflow-hidden')
  }

  closeMenu() {
    // Hide the menu
    this.menuTarget.classList.add('-translate-x-full')
    this.menuTarget.classList.remove('translate-x-0')

    // Hide backdrop
    this.hideBackdrop()

    // Allow body scroll
    document.body.classList.remove('overflow-hidden')
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.closeMenu()
    }
  }

  showBackdrop() {
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('hidden')
    }
  }

  hideBackdrop() {
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add('hidden')
    }
  }

  handleResize() {
    // Close mobile menu on desktop
    if (window.innerWidth >= 1024) {
      this.closeMenu()
    }
  }
}
