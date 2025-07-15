// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"

import Rails from "@rails/ujs"
Rails.start()

import "controllers"

// import * as ActiveStorage from "@rails/activestorage"
// import "channels"

// import "./controllers"
// import "./utils/api"
// import "./utils/notifications"

// Rails.start()
// Turbo.start()
// ActiveStorage.start()



// Global error handling
window.addEventListener('error', (event) => {
  console.error('Global error:', event.error)

  if (window.notifications) {
    window.notifications.show('An unexpected error occurred', 'error')
  }
})

// Handle unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason)

  if (window.notifications) {
    window.notifications.show('An unexpected error occurred', 'error')
  }
})

class AutoRefresh {
  constructor() {
    this.intervals = new Map()
  }

  start(key, callback, interval = 30000) {
    this.stop(key) // Clear existing interval

    const intervalId = setInterval(callback, interval)
    this.intervals.set(key, intervalId)
  }

  stop(key) {
    const intervalId = this.intervals.get(key)
    if (intervalId) {
      clearInterval(intervalId)
      this.intervals.delete(key)
    }
  }

  stopAll() {
    this.intervals.forEach((intervalId) => {
      clearInterval(intervalId)
    })
    this.intervals.clear()
  }
}

window.autoRefresh = new AutoRefresh()

window.addEventListener('beforeunload', () => {
  window.autoRefresh.stopAll()
})

// Theme management
class ThemeManager {
  constructor() {
    this.currentTheme = localStorage.getItem('theme') || 'light'
    this.applyTheme()
  }

  applyTheme() {
    document.documentElement.classList.toggle('dark', this.currentTheme === 'dark')
  }

  toggle() {
    this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light'
    localStorage.setItem('theme', this.currentTheme)
    this.applyTheme()
  }

  setTheme(theme) {
    this.currentTheme = theme
    localStorage.setItem('theme', theme)
    this.applyTheme()
  }
}

window.themeManager = new ThemeManager()
