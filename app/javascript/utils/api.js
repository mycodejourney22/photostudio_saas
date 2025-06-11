class ApiClient {
  constructor() {
    this.baseURL = window.location.origin
    this.defaultHeaders = {
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      'X-CSRF-Token': this.getCSRFToken()
    }
  }

  getCSRFToken() {
    return document.querySelector('[name="csrf-token"]').content
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`
    const config = {
      headers: { ...this.defaultHeaders, ...options.headers },
      ...options
    }

    try {
      const response = await fetch(url, config)

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const contentType = response.headers.get('content-type')
      if (contentType && contentType.includes('application/json')) {
        return await response.json()
      }

      return response
    } catch (error) {
      console.error('API request failed:', error)
      throw error
    }
  }

  get(endpoint, params = {}) {
    const url = new URL(`${this.baseURL}${endpoint}`)
    Object.keys(params).forEach(key => url.searchParams.append(key, params[key]))

    return this.request(url.pathname + url.search, {
      method: 'GET'
    })
  }

  post(endpoint, data = {}) {
    return this.request(endpoint, {
      method: 'POST',
      body: JSON.stringify(data)
    })
  }

  patch(endpoint, data = {}) {
    return this.request(endpoint, {
      method: 'PATCH',
      body: JSON.stringify(data)
    })
  }

  delete(endpoint) {
    return this.request(endpoint, {
      method: 'DELETE'
    })
  }
}

// Create global API client instance
window.api = new ApiClient()

// app/javascript/utils/notifications.js
class NotificationManager {
  constructor() {
    this.container = this.createContainer()
  }

  createContainer() {
    let container = document.getElementById('notifications-container')

    if (!container) {
      container = document.createElement('div')
      container.id = 'notifications-container'
      container.className = 'fixed top-4 right-4 z-50 space-y-2'
      document.body.appendChild(container)
    }

    return container
  }

  show(message, type = 'info', duration = 5000) {
    const notification = this.createNotification(message, type)
    this.container.appendChild(notification)

    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full', 'opacity-0')
    }, 10)

    // Auto remove
    if (duration > 0) {
      setTimeout(() => {
        this.remove(notification)
      }, duration)
    }

    return notification
  }

  createNotification(message, type) {
    const notification = document.createElement('div')
    notification.className = `
      transform translate-x-full opacity-0 transition-all duration-300 ease-in-out
      max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto overflow-hidden
      ${this.getTypeClasses(type)}
    `

    notification.innerHTML = `
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            ${this.getIcon(type)}
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="text-sm font-medium text-gray-900">${message}</p>
          </div>
          <div class="ml-4 flex-shrink-0 flex">
            <button class="notification-close bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `

    // Add close functionality
    notification.querySelector('.notification-close').addEventListener('click', () => {
      this.remove(notification)
    })

    return notification
  }

  remove(notification) {
    notification.classList.add('translate-x-full', 'opacity-0')

    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification)
      }
    }, 300)
  }

  getTypeClasses(type) {
    switch (type) {
      case 'success':
        return 'border-l-4 border-green-400'
      case 'error':
        return 'border-l-4 border-red-400'
      case 'warning':
        return 'border-l-4 border-yellow-400'
      default:
        return 'border-l-4 border-blue-400'
    }
  }

  getIcon(type) {
    const iconClass = 'h-6 w-6'

    switch (type) {
      case 'success':
        return `<svg class="${iconClass} text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>`
      case 'error':
        return `<svg class="${iconClass} text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>`
      case 'warning':
        return `<svg class="${iconClass} text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>`
      default:
        return `<svg class="${iconClass} text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>`
    }
  }
}

// Create global notification manager
window.notifications = new NotificationManager()
