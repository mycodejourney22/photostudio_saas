// app/javascript/controllers/public_booking_calendar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "monthHeader",
    "calendarGrid",
    "selectedDateText",
    "timeSlotsContainer",
    "timeSlots",
    "continueBtn",
    "emptyState"
  ]

  static values = {
    availableDates: Array,
    timeSlotsByDate: Object,
    tenantSlug: String,
    studioLocationId: Number,
    servicePackageId: Number,
    serviceTierId: Number
  }

  connect() {
    this.currentDate = new Date()
    this.selectedDate = null
    this.selectedTime = null
    this.renderCalendar()
  }

  renderCalendar() {
    const year = this.currentDate.getFullYear()
    const month = this.currentDate.getMonth()

    // Update month header
    this.monthHeaderTarget.textContent = this.currentDate.toLocaleDateString('en-US', {
      month: 'long',
      year: 'numeric'
    })

    // Clear grid
    this.calendarGridTarget.innerHTML = ''

    // Get first day of month and number of days
    const firstDay = new Date(year, month, 1)
    const lastDay = new Date(year, month + 1, 0)
    const startDate = new Date(firstDay)
    startDate.setDate(startDate.getDate() - firstDay.getDay())

    // Create calendar grid
    for (let i = 0; i < 42; i++) {
      const date = new Date(startDate)
      date.setDate(startDate.getDate() + i)

      const dayElement = this.createDayElement(date, month)
      this.calendarGridTarget.appendChild(dayElement)
    }
  }

  createDayElement(date, currentMonth) {
    const dayElement = document.createElement('button')
    const dateStr = date.toISOString().split('T')[0]
    const isCurrentMonth = date.getMonth() === currentMonth
    const isAvailable = this.availableDatesValue.includes(dateStr)
    const isToday = this.isToday(date)
    const isPast = date < new Date().setHours(0, 0, 0, 0)

    dayElement.className = this.getDayClasses(isCurrentMonth, isAvailable, isToday, isPast)
    dayElement.innerHTML = `
      <span class="text-sm font-medium">${date.getDate()}</span>
      ${isAvailable ? '<div class="w-1 h-1 bg-current rounded-full mx-auto mt-1"></div>' : ''}
    `

    if (isAvailable && !isPast) {
      dayElement.addEventListener('click', () => this.selectDate(date, dateStr))
    } else {
      dayElement.disabled = true
    }

    return dayElement
  }

  getDayClasses(isCurrentMonth, isAvailable, isToday, isPast) {
    let classes = 'p-2 h-12 flex flex-col items-center justify-center transition-all duration-200 '

    if (!isCurrentMonth) {
      classes += 'text-gray-300 cursor-not-allowed '
    } else if (isPast) {
      classes += 'text-gray-400 cursor-not-allowed '
    } else if (isAvailable) {
      classes += 'text-blue-600 hover:bg-blue-50 cursor-pointer rounded-lg '
      if (isToday) {
        classes += 'ring-2 ring-blue-500 '
      }
    } else {
      classes += 'text-gray-400 cursor-not-allowed '
    }

    return classes
  }

  isToday(date) {
    const today = new Date()
    return date.toDateString() === today.toDateString()
  }

  selectDate(date, dateStr) {
    this.selectedDate = dateStr

    // Update UI
    this.element.querySelectorAll('.calendar-day-selected').forEach(el => {
      el.classList.remove('calendar-day-selected', 'bg-blue-600', 'text-white')
    })

    event.target.closest('button').classList.add('calendar-day-selected', 'bg-blue-600', 'text-white')

    // Update selected date text
    this.selectedDateTextTarget.textContent = date.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })

    // Show time slots
    this.showTimeSlots(dateStr)
  }

  showTimeSlots(dateStr) {
    if (!this.hasTimeSlotsTarget) return

    const slots = this.timeSlotsByDateValue[dateStr] || []
    this.timeSlotsTarget.innerHTML = ''

    if (slots.length === 0) {
      this.timeSlotsTarget.innerHTML = '<p class="text-gray-500 text-center col-span-full">No available times for this date</p>'
    } else {
      slots.forEach(slot => {
        if (slot.available) {
          const slotElement = document.createElement('button')
          slotElement.className = 'time-slot p-3 rounded-lg border-2 border-gray-200 text-center transition-all duration-200 hover:border-blue-500 hover:bg-blue-50 focus:border-blue-500 focus:bg-blue-50 focus:outline-none'
          slotElement.innerHTML = `
            <div class="font-medium text-gray-900">${slot.time}</div>
            <div class="text-xs text-gray-500 mt-1">Available</div>
          `

          slotElement.addEventListener('click', () => this.selectTimeSlot(slotElement, slot.time))
          this.timeSlotsTarget.appendChild(slotElement)
        }
      })
    }

    // Show time slots container and hide empty state
    this.timeSlotsContainerTarget.classList.remove('hidden')
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add('hidden')
    }
  }

  selectTimeSlot(element, time) {
    this.selectedTime = time

    // Update UI
    this.element.querySelectorAll('.time-slot').forEach(slot => {
      slot.classList.remove('time-slot-selected', 'bg-blue-600', 'text-white', 'border-blue-600')
      slot.classList.add('border-gray-200')
      slot.querySelector('div:first-child').classList.remove('text-white')
      slot.querySelector('div:last-child').classList.remove('text-white')
    })

    element.classList.add('time-slot-selected', 'bg-blue-600', 'text-white', 'border-blue-600')
    element.classList.remove('border-gray-200')
    element.querySelector('div:first-child').classList.add('text-white')
    element.querySelector('div:last-child').classList.add('text-white')

    // Show continue button
    if (this.hasContinueBtnTarget) {
      this.continueBtnTarget.classList.remove('hidden')
    }
  }

  continue() {
    if (this.selectedDate && this.selectedTime) {
      const url = `/book/${this.tenantSlugValue}/details?` +
        `studio_location_id=${this.studioLocationIdValue}&` +
        `service_package_id=${this.servicePackageIdValue}&` +
        `service_tier_id=${this.serviceTierIdValue}&` +
        `date=${this.selectedDate}&` +
        `slot=${encodeURIComponent(this.selectedTime)}`

      window.location.href = url
    }
  }

  changeMonth(direction) {
    this.currentDate.setMonth(this.currentDate.getMonth() + direction)
    this.renderCalendar()

    // Clear selections when changing month
    this.selectedDate = null
    this.selectedTime = null

    // Reset UI
    this.selectedDateTextTarget.textContent = 'Select a date to see available times'
    this.timeSlotsContainerTarget.classList.add('hidden')
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove('hidden')
    }
    if (this.hasContinueBtnTarget) {
      this.continueBtnTarget.classList.add('hidden')
    }
  }

  // Action methods for template
  previousMonth() {
    this.changeMonth(-1)
  }

  nextMonth() {
    this.changeMonth(1)
  }
}
