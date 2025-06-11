import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "backdrop"]

  connect() {
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.handleResize)
  }

  disconnect() {
    window.removeEventListener('resize', this.handleResize)
  }

  toggleMenu() {
    const isOpen = !this.menuTarget.classList.contains('translate-x-full')

    if (isOpen) {
      this.closeMenu()
    } else {
      this.openMenu()
    }
  }

  openMenu() {
    this.menuTarget.classList.remove('translate-x-full')
    this.backdropTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  closeMenu() {
    this.menuTarget.classList.add('translate-x-full')
    this.backdropTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.closeMenu()
    }
  }

  handleResize() {
    // Close mobile menu on desktop
    if (window.innerWidth >= 768) {
      this.closeMenu()
    }
  }
}
