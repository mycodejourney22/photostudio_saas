// app/javascript/controllers/sales_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "itemsContainer",
    "total",
    "subtotal",
    "discount",
    "itemTotal",
    "paymentStatus",
    "paymentMethod",
    "amountPaid",
    "submitButton",
    "errorContainer"
  ]

  connect() {
    console.log("YESSSSSSSSS NOW")
    this.itemIndex = this.itemsContainerTarget.children.length
    this.updateTotal()
    // this.validateForm() // Initial validation
    this.addValidationListeners()
  }

  addValidationListeners() {
    // Add validation on form field changes
    this.element.addEventListener('input', (e) => {
      if (this.isValidationField(e.target)) {
        setTimeout(() => this.validateForm(), 100) // Small delay for calculations
      }
    })

    this.element.addEventListener('change', (e) => {
      if (this.isValidationField(e.target)) {
        this.validateForm()
      }
    })

    // Add blur validation for individual fields
    this.element.addEventListener('blur', (e) => {
      if (this.isValidationField(e.target)) {
        this.validateIndividualField(e.target)
      }
    }, true)
  }

  isValidationField(field) {
    return field.matches('input[name*="[name]"]') ||
           field.matches('input[name*="[unit_price]"]') ||
           field.matches('input[name*="[quantity]"]') ||
           field.matches('select[name*="payment_method"]') ||
           field.matches('input[name*="paid_amount"]')
  }

  validateIndividualField(field) {
    if (field.matches('input[name*="[name]"]')) {
      this.validateItemName(field)
    } else if (field.matches('input[name*="[unit_price]"]')) {
      this.validateItemPrice(field)
    } else if (field.matches('input[name*="[quantity]"]')) {
      this.validateItemQuantity(field)
    } else if (field.matches('select[name*="payment_method"]')) {
      this.validatePaymentMethod(field)
    } else if (field.matches('input[name*="paid_amount"]')) {
      this.validateAmountPaid(field)
    }
  }

  validateForm() {
    let isValid = true
    this.clearErrors()

    // Validate sale items
    const itemRows = this.itemsContainerTarget.querySelectorAll('.sale-item-row:not([data-destroy="true"])')

    if (itemRows.length === 0) {
      this.showError('At least one item is required')
      isValid = false
    }

    itemRows.forEach((row, index) => {
      const itemName = row.querySelector('input[name*="[name]"]')
      const itemPrice = row.querySelector('input[name*="[unit_price]"]')
      const itemQuantity = row.querySelector('input[name*="[quantity]"]')

      if (!this.validateItemName(itemName, index + 1)) isValid = false
      if (!this.validateItemPrice(itemPrice, index + 1)) isValid = false
      if (!this.validateItemQuantity(itemQuantity, index + 1)) isValid = false
    })

    // Validate payment fields
    const paymentMethod = this.element.querySelector('select[name*="payment_method"]')
    const amountPaid = this.element.querySelector('input[name*="paid_amount"]')

    if (!this.validatePaymentMethod(paymentMethod)) isValid = false
    if (!this.validateAmountPaid(amountPaid)) isValid = false

    // Enable/disable submit buttons
    this.toggleSubmitButtons(isValid)

    return isValid
  }

  validateItemName(field, itemNumber) {
    if (!field || !field.value.trim()) {
      this.addFieldError(field, `Item ${itemNumber}: Name is required`)
      return false
    }
    this.removeFieldError(field)
    return true
  }

  validateItemPrice(field, itemNumber) {
    const value = parseFloat(field?.value)
    if (!field || !field.value || isNaN(value) || value <= 0) {
      this.addFieldError(field, `Item ${itemNumber}: Price must be greater than 0`)
      return false
    }
    this.removeFieldError(field)
    return true
  }

  validateItemQuantity(field, itemNumber) {
    const value = parseInt(field?.value)
    if (!field || !field.value || isNaN(value) || value < 1) {
      this.addFieldError(field, `Item ${itemNumber}: Quantity must be at least 1`)
      return false
    }
    this.removeFieldError(field)
    return true
  }

  validatePaymentMethod(field) {
    if (!field) return true

    const value = field.value
    if (!value || value === '' || value === 'Select payment method...') {
      this.addFieldError(field, 'Payment method is required')
      return false
    }
    this.removeFieldError(field)
    return true
  }

  validateAmountPaid(field) {
    if (!field) return true

    const value = parseFloat(field.value)
    const total = this.calculateTotal()

    if (isNaN(value) || value < 0) {
      this.addFieldError(field, 'Amount paid must be 0 or greater')
      return false
    }

    if (value > total) {
      this.addFieldError(field, 'Amount paid cannot exceed total')
      return false
    }

    this.removeFieldError(field)
    return true
  }

  // Form submission handler
  handleSubmit(event) {
    if (!this.validateForm()) {
      event.preventDefault()
      this.showError('Please fix all validation errors before submitting')

      // Scroll to first error
      const firstError = this.element.querySelector('.field-error')
      if (firstError) {
        firstError.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }

      return false
    }
    return true
  }

  // Existing methods enhanced with validation
  addItem() {
    const newItemHtml = this.buildItemHtml(this.itemIndex)
    this.itemsContainerTarget.insertAdjacentHTML('beforeend', newItemHtml)
    this.itemIndex++
    this.updateTotal()
    this.validateForm() // Validate after adding item
  }

  removeItem(event) {
    const itemRow = event.target.closest('.sale-item-row')
    const destroyField = itemRow.querySelector('input[name*="_destroy"]')

    if (destroyField) {
      destroyField.value = "1"
      itemRow.style.display = "none"
      itemRow.setAttribute('data-destroy', 'true')
    } else {
      itemRow.remove()
    }

    this.updateTotal()
    this.validateForm() // Validate after removing item
  }

  itemChanged(event) {
    const itemRow = event.target.closest('.sale-item-row')
    this.updateItemTotal(itemRow)
    this.updateTotal()
    this.validateForm() // Validate after changes
  }

  updateItemTotal(itemRow) {
    const quantity = parseFloat(itemRow.querySelector('input[name*="[quantity]"]')?.value || 0)
    const unitPrice = parseFloat(itemRow.querySelector('input[name*="[unit_price]"]')?.value || 0)
    const total = quantity * unitPrice

    const totalField = itemRow.querySelector('[data-sales-form-target="itemTotal"], input[name*="[total_price]"]')
    if (totalField) {
      if (totalField.tagName === 'INPUT') {
        totalField.value = total.toFixed(2)
      } else {
        totalField.textContent = total.toFixed(2)
      }
    }
  }

  calculateTotal() {
    let total = 0
    const itemRows = this.itemsContainerTarget.querySelectorAll('.sale-item-row:not([data-destroy="true"])')

    itemRows.forEach(row => {
      const quantity = parseFloat(row.querySelector('input[name*="[quantity]"]')?.value || 0)
      const unitPrice = parseFloat(row.querySelector('input[name*="[unit_price]"]')?.value || 0)
      total += quantity * unitPrice
    })

    return total
  }

  updateTotal() {
    const total = this.calculateTotal()

    if (this.hasSubtotalTarget) {
      this.subtotalTarget.textContent = total.toFixed(2)
    }

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = total.toFixed(2)
    }

    this.updatePaymentStatus(total)
  }

  updatePaymentStatus(total) {
    if (!this.hasPaymentStatusTarget) return

    const amountPaidField = this.element.querySelector('input[name*="paid_amount"]')
    const amountPaid = parseFloat(amountPaidField?.value || 0)

    let status = 'Unpaid'
    let statusClass = 'text-red-600'

    if (amountPaid > 0) {
      if (amountPaid >= total) {
        status = 'Paid'
        statusClass = 'text-green-600'
      } else {
        status = 'Partial'
        statusClass = 'text-yellow-600'
      }
    }

    this.paymentStatusTarget.textContent = `${status} - ${amountPaid.toFixed(2)} of ${total.toFixed(2)}`
    this.paymentStatusTarget.className = statusClass
  }

  // Error handling methods
  addFieldError(field, message) {
    if (!field) return

    this.removeFieldError(field)

    field.classList.add('border-red-500', 'border-2')
    field.classList.remove('border-gray-300')

    const errorDiv = document.createElement('div')
    errorDiv.className = 'field-error text-red-500 text-sm mt-1'
    errorDiv.textContent = message

    field.parentNode.appendChild(errorDiv)
  }

  removeFieldError(field) {
    if (!field) return

    field.classList.remove('border-red-500', 'border-2')
    field.classList.add('border-gray-300')

    const existingError = field.parentNode.querySelector('.field-error')
    if (existingError) {
      existingError.remove()
    }
  }

  clearErrors() {
    // Clear general errors
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.innerHTML = ''
      this.errorContainerTarget.classList.add('hidden')
    }

    // Clear field errors
    this.element.querySelectorAll('.field-error').forEach(error => error.remove())
    this.element.querySelectorAll('.border-red-500').forEach(field => {
      field.classList.remove('border-red-500', 'border-2')
      field.classList.add('border-gray-300')
    })
  }

  showError(message) {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-md p-4 mb-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <p class="text-sm text-red-600">${message}</p>
            </div>
          </div>
        </div>
      `
      this.errorContainerTarget.classList.remove('hidden')
    }
  }

  toggleSubmitButtons(isValid) {
    const submitButtons = this.element.querySelectorAll('input[type="submit"], button[type="submit"]')
    submitButtons.forEach(button => {
      button.disabled = !isValid
      button.classList.toggle('opacity-50', !isValid)
      button.classList.toggle('cursor-not-allowed', !isValid)
    })
  }

  buildItemHtml(index) {
    return `
      <div class="sale-item-row bg-gray-50 rounded-lg border border-gray-200 p-4 mb-4">
        <input type="hidden" name="sale[sale_items_attributes][${index}][id]" value="">
        <input type="hidden" name="sale[sale_items_attributes][${index}][_destroy]" value="0">

        <div class="grid grid-cols-6 gap-4 mb-4">
          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Type</label>
            <select name="sale[sale_items_attributes][${index}][item_type]"
                    class="block w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    data-action="change->sales-form#itemChanged">
              <option value="service">Service</option>
              <option value="product">Product</option>
              <option value="package">Package</option>
            </select>
          </div>

          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">
              Item Name <span class="text-red-500">*</span>
            </label>
            <input type="text"
                   name="sale[sale_items_attributes][${index}][name]"
                   required
                   placeholder="Enter item name"
                   class="block w-full px-3 py-2 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                   data-action="change->sales-form#itemChanged">
          </div>

          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">
              Qty <span class="text-red-500">*</span>
            </label>
            <input type="number"
                   name="sale[sale_items_attributes][${index}][quantity]"
                   value="1"
                   min="1"
                   required
                   class="block w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                   data-action="change->sales-form#itemChanged">
          </div>

          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">
              Price <span class="text-red-500">*</span>
            </label>
            <input type="number"
                   name="sale[sale_items_attributes][${index}][unit_price]"
                   step="0.01"
                   min="0.01"
                   required
                   placeholder="0.00"
                   class="block w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                   data-action="change->sales-form#itemChanged">
          </div>

          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Total</label>
            <input type="number"
                   name="sale[sale_items_attributes][${index}][total_price]"
                   step="0.01"
                   readonly
                   class="block w-full px-2 py-1 text-sm border border-gray-300 rounded bg-gray-50 text-gray-500">
          </div>

          <div class="flex items-end">
            <button type="button"
                    data-action="click->sales-form#removeItem"
                    class="px-3 py-2 text-red-600 hover:text-red-800 border border-red-300 rounded hover:bg-red-50 transition-colors text-sm">
              Remove
            </button>
          </div>
        </div>

        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Description (optional)</label>
          <textarea name="sale[sale_items_attributes][${index}][description]"
                    rows="2"
                    placeholder="Item description or details..."
                    class="block w-full px-3 py-2 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"></textarea>
        </div>
      </div>
    `
  }
}
