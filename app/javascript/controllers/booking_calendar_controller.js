// app/javascript/controllers/booking_calendar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "calendarGrid",
    "monthHeader",
    "selectedDateDisplay",
    "selectedDateText",
    "timeSlotsContainer",
    "timeSlots",
    "continueBtn",
    "emptyState"
  ]

  static values = {
    availableDates: Array,
    timeSlotsByDate: Object,
    studioLocationId: String,
    servicePackageId: String,
    serviceTierId: String
  }

  connect() {
    this.currentMonth = new Date()
    this.selectedDate = null
    this.selectedTime = null

    this.initCalendar()
  }

  initCalendar() {
    this.renderCalendar()
    // Ensure time slots are hidden initially
    this.timeSlotsContainerTarget.classList.add('hidden')
    this.emptyStateTarget.classList.remove('hidden')
  }

  renderCalendar() {
    if (!this.hasCalendarGridTarget || !this.hasMonthHeaderTarget) return

    this.monthHeaderTarget.textContent = this.currentMonth.toLocaleDateString('en-US', {
      month: 'long',
      year: 'numeric'
    })

    const firstDay = new Date(this.currentMonth.getFullYear(), this.currentMonth.getMonth(), 1)
    const startDate = new Date(firstDay)
    startDate.setDate(startDate.getDate() - firstDay.getDay())

    this.calendarGridTarget.innerHTML = ''

    // console.log('Calendar generation debug:', {
    //   currentMonth: this.currentMonth.toString(),
    //   firstDay: firstDay.toString(),
    //   startDate: startDate.toString(),
    //   firstDayOfWeek: firstDay.getDay()
    // })

    // Create 6 weeks of calendar (42 days)
    for (let i = 0; i < 42; i++) {
      const date = new Date(startDate)
      date.setDate(startDate.getDate() + i)

      // Fix: Create dateStr in local timezone to avoid UTC conversion issues
      const year = date.getFullYear()
      const month = String(date.getMonth() + 1).padStart(2, '0')
      const day = String(date.getDate()).padStart(2, '0')
      const dateStr = `${year}-${month}-${day}`

      const isCurrentMonth = date.getMonth() === this.currentMonth.getMonth()
      const isToday = date.toDateString() === new Date().toDateString()
      const isAvailable = this.availableDatesValue.includes(dateStr)
      const isPast = date < new Date().setHours(0,0,0,0)

      const dayElement = document.createElement('div')
      dayElement.className = 'text-center'

      const button = document.createElement('button')
      button.textContent = date.getDate()
      button.className = 'w-10 h-10 rounded-lg text-sm font-medium transition-all duration-200 '

      // Debug: Log first few dates to see what's happening
      // if (i < 10) {
      //   console.log(`Day ${i}:`, {
      //     date: date.toString(),
      //     dateStr,
      //     dayOfMonth: date.getDate(),
      //     isCurrentMonth,
      //     isAvailable
      //   })
      // }

      if (!isCurrentMonth) {
        button.className += 'text-gray-300 cursor-not-allowed'
        button.disabled = true
      } else if (isPast) {
        button.className += 'text-gray-400 cursor-not-allowed'
        button.disabled = true
      } else if (isToday) {
        button.className += 'bg-yellow-100 text-yellow-600 border-2 border-yellow-300'
        if (isAvailable) {
          button.className += ' cursor-pointer date-btn hover:bg-yellow-200'
          button.dataset.date = dateStr
          button.addEventListener('click', () => this.selectDate(dateStr, button))
        } else {
          button.disabled = true
          button.className += ' cursor-not-allowed'
        }
      } else if (isAvailable) {
        button.className += 'text-gray-700 hover:bg-blue-50 hover:text-blue-600 cursor-pointer date-btn'
        button.dataset.date = dateStr
        button.addEventListener('click', () => this.selectDate(dateStr, button))
      } else {
        button.className += 'text-gray-400 cursor-not-allowed'
        button.disabled = true
      }

      dayElement.appendChild(button)
      this.calendarGridTarget.appendChild(dayElement)
    }

    // console.log('Available dates from Rails:', this.availableDatesValue)
  }

  changeMonth(direction) {
    this.currentMonth.setMonth(this.currentMonth.getMonth() + direction)
    this.renderCalendar()
  }

  selectDate(dateStr, buttonElement) {
    this.selectedDate = dateStr

    // Update UI
    this.element.querySelectorAll('.date-btn').forEach(btn => {
      btn.classList.remove('selected-date', 'text-white')
      btn.classList.add('text-gray-700')
    })

    buttonElement.classList.add('selected-date', 'text-white')
    buttonElement.classList.remove('text-gray-700')

    // Show selected date - Timezone-safe approach for Nigerian timezone
    if (this.hasSelectedDateDisplayTarget && this.hasSelectedDateTextTarget) {
      // Parse date parts manually to avoid timezone conversion
      const [year, month, day] = dateStr.split('-').map(Number)

      // Create date object in local timezone at noon to avoid DST issues
      const dateObj = new Date(year, month - 1, day, 12, 0, 0)

      // Alternative approach: Build the formatted string manually to avoid timezone issues
      const monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ]

      const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

      // Get the day of week correctly
      const dayOfWeek = dayNames[dateObj.getDay()]
      const monthName = monthNames[month - 1]

      const formattedDate = `${dayOfWeek}, ${monthName} ${day}, ${year}`

      // console.log('Date debug:', {
      //   input: dateStr,
      //   parsed: { year, month, day },
      //   dateObj: dateObj.toString(),
      //   dayOfWeek,
      //   formatted: formattedDate
      // })

      this.selectedDateTextTarget.textContent = formattedDate
      this.selectedDateDisplayTarget.classList.remove('hidden')
    }

    // Load time slots
    this.loadTimeSlots(dateStr)

    // Hide empty state and show time slots
    this.emptyStateTarget.classList.add('hidden')
    this.timeSlotsContainerTarget.classList.remove('hidden')
  }

  loadTimeSlots(dateStr) {
    if (!this.hasTimeSlotsTarget) return

    const slots = this.timeSlotsByDateValue[dateStr] || []
    this.timeSlotsTarget.innerHTML = ''

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

  selectTimeSlot(element, time) {
    this.selectedTime = time

    // Update UI
    this.element.querySelectorAll('.time-slot').forEach(slot => {
      slot.classList.remove('available-time', 'border-blue-500', 'text-white')
      slot.classList.add('border-gray-200')
      slot.querySelector('div:first-child').classList.remove('text-white')
      slot.querySelector('div:last-child').classList.remove('text-white')
    })

    element.classList.add('available-time', 'border-blue-500', 'text-white')
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
      const url = `/book/location/${this.studioLocationIdValue}/service/${this.servicePackageIdValue}/tier/${this.serviceTierIdValue}/details?date=${this.selectedDate}&slot=${encodeURIComponent(this.selectedTime)}`
      window.location.href = url
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
