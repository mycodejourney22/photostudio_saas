import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"
import TomSelect from "tom-select"

export default class extends Controller {
  static targets = ["dateInput", "timeInput", "customerSelect", "staffSelect", "studioSelect"]
  static values = {
    availabilityUrl: String,
    customersUrl: String
  }

  connect() {
    this.initializeDatePicker()
    this.initializeSelects()
    this.bindEvents()
  }

  disconnect() {
    this.cleanup()
  }

  initializeDatePicker() {
    this.datePicker = flatpickr(this.dateInputTarget, {
      minDate: "today",
      dateFormat: "Y-m-d",
      onChange: (selectedDates) => {
        if (selectedDates.length > 0) {
          this.loadAvailableSlots(selectedDates[0])
        }
      }
    })
  }

  initializeSelects() {
    // Customer select with search and create option
    this.customerSelect = new TomSelect(this.customerSelectTarget, {
      valueField: 'id',
      labelField: 'name',
      searchField: ['name', 'email'],
      load: (query, callback) => {
        this.searchCustomers(query, callback)
      },
      create: (input) => {
        return {
          id: 'new',
          name: input,
          email: input
        }
      },
      render: {
        option: (item) => {
          return `<div class="py-2 px-3">
            <div class="font-medium">${item.name}</div>
            <div class="text-sm text-gray-500">${item.email || ''}</div>
          </div>`
        }
      }
    })

    // Staff select
    if (this.hasStaffSelectTarget) {
      this.staffSelect = new TomSelect(this.staffSelectTarget, {
        placeholder: 'Select staff member...'
      })
    }

    // Studio select
    if (this.hasStudioSelectTarget) {
      this.studioSelect = new TomSelect(this.studioSelectTarget, {
        placeholder: 'Select studio...'
      })
    }
  }

  async searchCustomers(query, callback) {
    if (!query.length) return callback()

    try {
      const response = await fetch(`${this.customersUrlValue}?search=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const data = await response.json()
        const customers = data.data.map(customer => ({
          id: customer.id,
          name: customer.attributes.full_name,
          email: customer.attributes.email
        }))
        callback(customers)
      }
    } catch (error) {
      console.error('Failed to search customers:', error)
      callback()
    }
  }

  async loadAvailableSlots(date) {
    try {
      const response = await fetch(`${this.availabilityUrlValue}?date=${date.toISOString().split('T')[0]}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const slots = await response.json()
        this.updateTimeSlots(slots)
      }
    } catch (error) {
      console.error('Failed to load available slots:', error)
    }
  }

  updateTimeSlots(slots) {
    const timeSelect = this.timeInputTarget
    timeSelect.innerHTML = '<option value="">Select time...</option>'

    slots.forEach(slot => {
      const option = document.createElement('option')
      option.value = slot.time
      option.textContent = slot.display_time
      option.disabled = !slot.available
      timeSelect.appendChild(option)
    })
  }

  bindEvents() {
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
  }

  async handleSubmit(event) {
    event.preventDefault()

    const submitButton = this.element.querySelector('[type="submit"]')
    const originalText = submitButton.textContent

    try {
      submitButton.disabled = true
      submitButton.textContent = 'Saving...'

      const formData = new FormData(this.element)
      const response = await fetch(this.element.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        window.location.href = response.url || '/appointments'
      } else {
        const errorData = await response.json()
        this.displayErrors(errorData.errors)
      }
    } catch (error) {
      console.error('Failed to submit form:', error)
      this.showNotification('Failed to save appointment', 'error')
    } finally {
      submitButton.disabled = false
      submitButton.textContent = originalText
    }
  }

  displayErrors(errors) {
    // Clear previous errors
    this.element.querySelectorAll('.error-message').forEach(el => el.remove())

    Object.keys(errors).forEach(field => {
      const input = this.element.querySelector(`[name*="${field}"]`)
      if (input) {
        const errorDiv = document.createElement('div')
        errorDiv.className = 'error-message text-red-600 text-sm mt-1'
        errorDiv.textContent = errors[field][0]
        input.parentNode.appendChild(errorDiv)
      }
    })
  }

  showNotification(message, type = 'info') {
    // Implementation for toast notifications
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 ${
      type === 'error' ? 'bg-red-500 text-white' : 'bg-green-500 text-white'
    }`
    notification.textContent = message

    document.body.appendChild(notification)

    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  cleanup() {
    if (this.datePicker) {
      this.datePicker.destroy()
    }
    if (this.customerSelect) {
      this.customerSelect.destroy()
    }
    if (this.staffSelect) {
      this.staffSelect.destroy()
    }
    if (this.studioSelect) {
      this.studioSelect.destroy()
    }
  }
}
