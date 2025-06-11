import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "progress", "error"]
  static values = {
    maxSize: Number,
    acceptedTypes: Array,
    uploadUrl: String
  }

  connect() {
    this.maxSizeValue = this.maxSizeValue || 10 * 1024 * 1024 // 10MB default
    this.acceptedTypesValue = this.acceptedTypesValue || ['image/jpeg', 'image/png', 'image/webp']
  }

  handleFileSelect(event) {
    const files = Array.from(event.target.files)

    if (files.length === 0) return

    this.clearError()
    this.processFiles(files)
  }

  processFiles(files) {
    files.forEach(file => {
      if (this.validateFile(file)) {
        this.uploadFile(file)
      }
    })
  }

  validateFile(file) {
    // Check file size
    if (file.size > this.maxSizeValue) {
      this.showError(`File size must be less than ${this.formatFileSize(this.maxSizeValue)}`)
      return false
    }

    // Check file type
    if (!this.acceptedTypesValue.includes(file.type)) {
      this.showError(`File type ${file.type} is not supported`)
      return false
    }

    return true
  }

  async uploadFile(file) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('authenticity_token', this.getCSRFToken())

    try {
      this.showProgress(0)

      const response = await fetch(this.uploadUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const result = await response.json()
        this.handleUploadSuccess(result)
      } else {
        const error = await response.json()
        this.showError(error.message || 'Upload failed')
      }
    } catch (error) {
      console.error('Upload error:', error)
      this.showError('Upload failed. Please try again.')
    } finally {
      this.hideProgress()
    }
  }

  handleUploadSuccess(result) {
    if (this.hasPreviewTarget) {
      this.updatePreview(result.url)
    }

    // Dispatch custom event for parent components
    this.element.dispatchEvent(new CustomEvent('upload:success', {
      detail: result,
      bubbles: true
    }))
  }

  updatePreview(imageUrl) {
    if (this.previewTarget.tagName === 'IMG') {
      this.previewTarget.src = imageUrl
      this.previewTarget.classList.remove('hidden')
    } else {
      this.previewTarget.style.backgroundImage = `url(${imageUrl})`
      this.previewTarget.classList.add('bg-cover', 'bg-center')
    }
  }

  showProgress(percentage) {
    if (this.hasProgressTarget) {
      this.progressTarget.style.width = `${percentage}%`
      this.progressTarget.parentElement.classList.remove('hidden')
    }
  }

  hideProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.parentElement.classList.add('hidden')
    }
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove('hidden')
    }
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add('hidden')
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  getCSRFToken() {
    return document.querySelector('[name="csrf-token"]').content
  }
}
