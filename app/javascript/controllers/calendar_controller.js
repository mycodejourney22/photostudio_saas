import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["calendar", "eventModal", "eventForm"]
  static values = {
    eventsUrl: String,
    createUrl: String,
    updateUrl: String
  }

  connect() {
    this.initializeCalendar()
    this.bindEvents()
  }

  async initializeCalendar() {
    // Dynamic import for FullCalendar to reduce bundle size
    const { Calendar } = await import('@fullcalendar/core')
    const dayGridPlugin = await import('@fullcalendar/daygrid')
    const timeGridPlugin = await import('@fullcalendar/timegrid')
    const interactionPlugin = await import('@fullcalendar/interaction')

    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [dayGridPlugin.default, timeGridPlugin.default, interactionPlugin.default],
      initialView: 'timeGridWeek',
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,timeGridDay'
      },
      events: this.eventsUrlValue,
      selectable: true,
      selectMirror: true,
      dayMaxEvents: true,
      weekends: true,
      businessHours: {
        daysOfWeek: [1, 2, 3, 4, 5, 6], // Monday - Saturday
        startTime: '09:00',
        endTime: '18:00'
      },
      select: this.handleDateSelect.bind(this),
      eventClick: this.handleEventClick.bind(this),
      eventDrop: this.handleEventDrop.bind(this),
      eventResize: this.handleEventResize.bind(this),
      loading: this.handleLoading.bind(this)
    })

    this.calendar.render()
  }

  handleDateSelect(selectInfo) {
    this.openEventModal({
      start: selectInfo.start,
      end: selectInfo.end,
      allDay: selectInfo.allDay
    })
  }

  handleEventClick(clickInfo) {
    this.openEventModal({
      id: clickInfo.event.id,
      title: clickInfo.event.title,
      start: clickInfo.event.start,
      end: clickInfo.event.end,
      extendedProps: clickInfo.event.extendedProps
    })
  }

  async handleEventDrop(dropInfo) {
    try {
      await this.updateEvent(dropInfo.event.id, {
        scheduled_at: dropInfo.event.start.toISOString()
      })

      this.showNotification('Appointment rescheduled successfully', 'success')
    } catch (error) {
      dropInfo.revert()
      this.showNotification('Failed to reschedule appointment', 'error')
    }
  }

  async handleEventResize(resizeInfo) {
    try {
      const duration = Math.round((resizeInfo.event.end - resizeInfo.event.start) / (1000 * 60))

      await this.updateEvent(resizeInfo.event.id, {
        duration_minutes: duration
      })

      this.showNotification('Appointment duration updated', 'success')
    } catch (error) {
      resizeInfo.revert()
      this.showNotification('Failed to update appointment duration', 'error')
    }
  }

  handleLoading(isLoading) {
    const loadingEl = this.element.querySelector('.loading-indicator')
    if (loadingEl) {
      loadingEl.style.display = isLoading ? 'block' : 'none'
    }
  }

  openEventModal(eventData = {}) {
    if (this.hasEventModalTarget) {
      // Populate form with event data
      this.populateForm(eventData)
      this.eventModalTarget.classList.remove('hidden')
    }
  }

  closeEventModal() {
    if (this.hasEventModalTarget) {
      this.eventModalTarget.classList.add('hidden')
      this.clearForm()
    }
  }

  populateForm(eventData) {
    if (!this.hasEventFormTarget) return

    const form = this.eventFormTarget

    // Set form action based on whether it's create or update
    if (eventData.id) {
      form.action = this.updateUrlValue.replace(':id', eventData.id)
      form.querySelector('[name="_method"]').value = 'PATCH'
    } else {
      form.action = this.createUrlValue
      form.querySelector('[name="_method"]').value = 'POST'
    }

    // Populate form fields
    Object.keys(eventData).forEach(key => {
      const input = form.querySelector(`[name*="${key}"]`)
      if (input) {
        if (input.type === 'datetime-local') {
          input.value = eventData[key].toISOString().slice(0, 16)
        } else {
          input.value = eventData[key]
        }
      }
    })
  }

  clearForm() {
    if (this.hasEventFormTarget) {
      this.eventFormTarget.reset()
    }
  }

  async updateEvent(eventId, updates) {
    const response = await fetch(`/appointments/${eventId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ appointment: updates })
    })

    if (!response.ok) {
      throw new Error('Update failed')
    }

    return response.json()
  }

  bindEvents() {
    // Modal close events
    this.element.addEventListener('click', (event) => {
      if (event.target.classList.contains('modal-close')) {
        this.closeEventModal()
      }
    })

    // Form submission
    if (this.hasEventFormTarget) {
      this.eventFormTarget.addEventListener('submit', this.handleFormSubmit.bind(this))
    }
  }

  async handleFormSubmit(event) {
    event.preventDefault()

    try {
      const formData = new FormData(event.target)
      const response = await fetch(event.target.action, {
        method: formData.get('_method') || 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        this.calendar.refetchEvents()
        this.closeEventModal()
        this.showNotification('Appointment saved successfully', 'success')
      } else {
        const errorData = await response.json()
        this.displayFormErrors(errorData.errors)
      }
    } catch (error) {
      console.error('Form submission failed:', error)
      this.showNotification('Failed to save appointment', 'error')
    }
  }

  displayFormErrors(errors) {
    // Similar to appointment form error display
    this.eventFormTarget.querySelectorAll('.error-message').forEach(el => el.remove())

    Object.keys(errors).forEach(field => {
      const input = this.eventFormTarget.querySelector(`[name*="${field}"]`)
      if (input) {
        const errorDiv = document.createElement('div')
        errorDiv.className = 'error-message text-red-600 text-sm mt-1'
        errorDiv.textContent = errors[field][0]
        input.parentNode.appendChild(errorDiv)
      }
    })
  }

  showNotification(message, type = 'info') {
    // Reuse notification system from appointment form
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
}
