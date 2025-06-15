// app/javascript/controllers/staff_assignment_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "photographerSelect",
    "editorSelect",
    "photographerDisplay",
    "editorDisplay",
    "assignButton",
    "removeButton"
  ]

  static values = {
    appointmentId: Number,
    updateUrl: String
  }

  connect() {
    this.setupEventListeners()
  }

  // Assign photographer
  async assignPhotographer(event) {
    const staffId = event.target.value
    if (!staffId) return

    try {
      const response = await this.makeAssignmentRequest('photographer', staffId)
      if (response.success) {
        this.updatePhotographerDisplay(response.staff_name, staffId)
        this.showNotification(response.message, 'success')
      } else {
        this.showNotification(response.message, 'error')
      }
    } catch (error) {
      this.showNotification('Failed to assign photographer', 'error')
      console.error('Assignment error:', error)
    }
  }

  // Assign editor
  async assignEditor(event) {
    const staffId = event.target.value
    if (!staffId) return

    try {
      const response = await this.makeAssignmentRequest('editor', staffId)
      if (response.success) {
        this.updateEditorDisplay(response.staff_name, staffId)
        this.showNotification(response.message, 'success')
      } else {
        this.showNotification(response.message, 'error')
      }
    } catch (error) {
      this.showNotification('Failed to assign editor', 'error')
      console.error('Assignment error:', error)
    }
  }

  // Remove photographer assignment
  async removePhotographer(event) {
    event.preventDefault()

    try {
      const response = await this.makeRemovalRequest('photographer')
      if (response.success) {
        this.clearPhotographerDisplay()
        this.showNotification('Photographer assignment removed', 'success')
      } else {
        this.showNotification(response.message, 'error')
      }
    } catch (error) {
      this.showNotification('Failed to remove photographer', 'error')
      console.error('Removal error:', error)
    }
  }

  // Remove editor assignment
  async removeEditor(event) {
    event.preventDefault()

    try {
      const response = await this.makeRemovalRequest('editor')
      if (response.success) {
        this.clearEditorDisplay()
        this.showNotification('Editor assignment removed', 'success')
      } else {
        this.showNotification(response.message, 'error')
      }
    } catch (error) {
      this.showNotification('Failed to remove editor', 'error')
      console.error('Removal error:', error)
    }
  }

  // Quick assign from button click
  async quickAssign(event) {
    event.preventDefault()

    const staffId = event.target.dataset.staffId
    const assignmentType = event.target.dataset.assignmentType

    if (!staffId || !assignmentType) return

    try {
      const response = await this.makeAssignmentRequest(assignmentType, staffId)
      if (response.success) {
        if (assignmentType === 'photographer') {
          this.updatePhotographerDisplay(response.staff_name, staffId)
        } else {
          this.updateEditorDisplay(response.staff_name, staffId)
        }
        this.showNotification(response.message, 'success')
      } else {
        this.showNotification(response.message, 'error')
      }
    } catch (error) {
      this.showNotification(`Failed to assign ${assignmentType}`, 'error')
      console.error('Quick assignment error:', error)
    }
  }

  // Private methods
  async makeAssignmentRequest(assignmentType, staffId) {
    const response = await fetch(`/appointments/${this.appointmentIdValue}/assign_staff`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        assignment_type: assignmentType,
        staff_member_id: staffId
      })
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    return await response.json()
  }

  async makeRemovalRequest(assignmentType) {
    const response = await fetch(`/appointments/${this.appointmentIdValue}/assign_staff`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        assignment_type: assignmentType,
        staff_member_id: null
      })
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    return await response.json()
  }

  updatePhotographerDisplay(staffName, staffId) {
    if (this.hasPhotographerDisplayTarget) {
      this.photographerDisplayTarget.innerHTML = `
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-3">
              <svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clip-rule="evenodd"/>
              </svg>
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">${staffName}</p>
              <p class="text-xs text-gray-500">Photographer</p>
            </div>
          </div>
          <button type="button"
                  class="text-red-400 hover:text-red-600 transition-colors"
                  data-action="click->staff-assignment#removePhotographer"
                  title="Remove Assignment">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      `
    }

    if (this.hasPhotographerSelectTarget) {
      this.photographerSelectTarget.value = staffId
    }
  }

  updateEditorDisplay(staffName, staffId) {
    if (this.hasEditorDisplayTarget) {
      this.editorDisplayTarget.innerHTML = `
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center mr-3">
              <svg class="w-4 h-4 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
                <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z"/>
              </svg>
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">${staffName}</p>
              <p class="text-xs text-gray-500">Editor</p>
            </div>
          </div>
          <button type="button"
                  class="text-red-400 hover:text-red-600 transition-colors"
                  data-action="click->staff-assignment#removeEditor"
                  title="Remove Assignment">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      `
    }

    if (this.hasEditorSelectTarget) {
      this.editorSelectTarget.value = staffId
    }
  }

  clearPhotographerDisplay() {
    if (this.hasPhotographerDisplayTarget) {
      this.photographerDisplayTarget.innerHTML = `
        <div class="text-center py-4">
          <div class="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-2">
            <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
          </div>
          <p class="text-sm text-gray-500">No photographer assigned</p>
        </div>
      `
    }

    if (this.hasPhotographerSelectTarget) {
      this.photographerSelectTarget.value = ''
    }
  }

  clearEditorDisplay() {
    if (this.hasEditorDisplayTarget) {
      this.editorDisplayTarget.innerHTML = `
        <div class="text-center py-4">
          <div class="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-2">
            <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
          </div>
          <p class="text-sm text-gray-500">No editor assigned</p>
        </div>
      `
    }

    if (this.hasEditorSelectTarget) {
      this.editorSelectTarget.value = ''
    }
  }

  setupEventListeners() {
    if (this.hasPhotographerSelectTarget) {
      this.photographerSelectTarget.addEventListener('change', this.assignPhotographer.bind(this))
    }

    if (this.hasEditorSelectTarget) {
      this.editorSelectTarget.addEventListener('change', this.assignEditor.bind(this))
    }
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  showNotification(message, type = 'info') {
    // Create a simple notification
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg max-w-sm ${
      type === 'success' ? 'bg-green-500 text-white' :
      type === 'error' ? 'bg-red-500 text-white' :
      'bg-blue-500 text-white'
    }`
    notification.textContent = message

    document.body.appendChild(notification)

    // Auto-remove after 3 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification)
      }
    }, 3000)
  }
}
