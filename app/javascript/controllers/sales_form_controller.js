// app/javascript/controllers/sales_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "saleType",
    "appointmentField",
    "appointmentSelect",
    "customerField",
    "customerSelect",
    "customerName",
    "customerEmail",
    "customerPhone",
    "saleItemsContainer",
    "addItemButton",
    "totalAmount",
    "itemTemplate",
    "paymentStatus",
    "partialPaymentAmount"
  ]

  static values = {
    appointments: Array,
    customers: Array,
    serviceTiers: Array
  }

  connect() {
    this.updateFieldVisibility()
    this.calculateTotal()
    this.setupAutocomplete()
    this.setupPaymentStatusToggle()
  }

  // Handle payment status change
  paymentStatusChanged() {
    this.togglePartialPaymentField()
  }

  togglePartialPaymentField() {
    const paymentStatusSelect = document.querySelector('select[name="sale[payment_status]"]')
    const partialAmountDiv = document.getElementById('partial-payment-amount')

    if (paymentStatusSelect && partialAmountDiv) {
      if (paymentStatusSelect.value === 'partial') {
        partialAmountDiv.style.display = 'block'
      } else {
        partialAmountDiv.style.display = 'none'
      }
    }
  }

  setupPaymentStatusToggle() {
    const paymentStatusSelect = document.querySelector('select[name="sale[payment_status]"]')
    if (paymentStatusSelect) {
      paymentStatusSelect.addEventListener('change', () => {
        this.togglePartialPaymentField()
      })
      // Initial call
      this.togglePartialPaymentField()
    }
  }

  // Handle sale type change
  saleTypeChanged() {
    this.updateFieldVisibility()

    if (this.saleTypeTarget.value === 'appointment') {
      this.clearManualCustomerFields()
    } else {
      this.clearAppointmentSelection()
    }
  }

  // Handle appointment selection
  appointmentChanged() {
    const appointmentId = this.appointmentSelectTarget.value
    if (!appointmentId) return

    const appointment = this.appointmentsValue.find(a => a.id == appointmentId)
    if (appointment) {
      this.prefillFromAppointment(appointment)
    }
  }

  // Handle customer selection
  customerChanged() {
    const customerId = this.customerSelectTarget.value
    if (!customerId) return

    const customer = this.customersValue.find(c => c.id == customerId)
    if (customer) {
      this.prefillFromCustomer(customer)
    }
  }

  // Add new sale item
  addSaleItem(event) {
    event.preventDefault()

    const template = this.itemTemplateTarget.content.cloneNode(true)
    const container = template.querySelector('.sale-item-row')

    // Update field names and IDs to be unique
    const itemCount = this.saleItemsContainerTarget.children.length
    this.updateItemFieldNames(container, itemCount)

    this.saleItemsContainerTarget.appendChild(template)
    this.calculateTotal()

    // Focus on the new item's name field
    const newNameField = container.querySelector('input[name*="[name]"]')
    if (newNameField) newNameField.focus()
  }

  // Remove sale item
  removeSaleItem(event) {
    event.preventDefault()

    const itemRow = event.target.closest('.sale-item-row')
    const destroyField = itemRow.querySelector('input[name*="[_destroy]"]')

    if (destroyField) {
      // Mark for destruction if it's an existing record
      destroyField.value = '1'
      itemRow.style.display = 'none'
    } else {
      // Remove from DOM if it's a new record
      itemRow.remove()
    }

    this.calculateTotal()
  }

  // Calculate item total when quantity or price changes
  itemChanged(event) {
    const itemRow = event.target.closest('.sale-item-row')
    this.calculateItemTotal(itemRow)
    this.calculateTotal()
  }

  // Quick add preset items
  addServiceItem(event) {
    event.preventDefault()

    const serviceId = event.target.dataset.serviceId
    const serviceTier = this.servicetiersValue.find(s => s.id == serviceId)

    if (serviceTier) {
      this.addSaleItem(event)
      const newItem = this.saleItemsContainerTarget.lastElementChild

      // Prefill with service data
      newItem.querySelector('select[name*="[item_type]"]').value = 'service'
      newItem.querySelector('input[name*="[name]"]').value = serviceTier.name
      newItem.querySelector('input[name*="[description]"]').value = serviceTier.description
      newItem.querySelector('input[name*="[unit_price]"]').value = serviceTier.base_price
      newItem.querySelector('input[name*="[duration_minutes]"]').value = serviceTier.duration_minutes
      newItem.querySelector('select[name*="[service_tier_id]"]').value = serviceId

      this.calculateItemTotal(newItem)
      this.calculateTotal()
    }
  }

  addProductItem(event) {
    event.preventDefault()

    const productType = event.target.dataset.productType
    const basePrice = event.target.dataset.basePrice || '0'

    this.addSaleItem(event)
    const newItem = this.saleItemsContainerTarget.lastElementChild

    // Prefill with product data
    newItem.querySelector('select[name*="[item_type]"]').value = 'product'
    newItem.querySelector('input[name*="[name]"]').value = productType
    newItem.querySelector('input[name*="[unit_price]"]').value = basePrice
    newItem.querySelector('input[name*="[product_category]"]').value = productType.toLowerCase()

    this.calculateItemTotal(newItem)
    this.calculateTotal()
  }

  // Private methods
  updateFieldVisibility() {
    const saleType = this.saleTypeTarget.value

    if (this.hasAppointmentFieldTarget) {
      this.appointmentFieldTarget.style.display =
        saleType === 'appointment' ? 'block' : 'none'
    }

    if (this.hasCustomerFieldTarget) {
      this.customerFieldTarget.style.display =
        saleType === 'appointment' ? 'none' : 'block'
    }
  }

  clearManualCustomerFields() {
    if (this.hasCustomerSelectTarget) this.customerSelectTarget.value = ''
    if (this.hasCustomerNameTarget) this.customerNameTarget.value = ''
    if (this.hasCustomerEmailTarget) this.customerEmailTarget.value = ''
    if (this.hasCustomerPhoneTarget) this.customerPhoneTarget.value = ''
  }

  clearAppointmentSelection() {
    if (this.hasAppointmentSelectTarget) this.appointmentSelectTarget.value = ''
  }

  prefillFromAppointment(appointment) {
    // Prefill customer info from appointment
    this.customerNameTarget.value = appointment.customer_name
    this.customerEmailTarget.value = appointment.customer_email || ''
    this.customerPhoneTarget.value = appointment.customer_phone || ''

    // Clear existing items and add appointment service
    this.clearAllItems()
    this.addAppointmentServiceItem(appointment)
  }

  prefillFromCustomer(customer) {
    this.customerNameTarget.value = `${customer.first_name} ${customer.last_name}`
    this.customerEmailTarget.value = customer.email || ''
    this.customerPhoneTarget.value = customer.phone || ''
  }

  addAppointmentServiceItem(appointment) {
    this.addSaleItem({ preventDefault: () => {} })
    const newItem = this.saleItemsContainerTarget.lastElementChild

    newItem.querySelector('select[name*="[item_type]"]').value = 'service'
    newItem.querySelector('input[name*="[name]"]').value = appointment.service_name
    newItem.querySelector('input[name*="[description]"]').value = `${appointment.session_type} session`
    newItem.querySelector('input[name*="[unit_price]"]').value = appointment.price
    newItem.querySelector('input[name*="[duration_minutes]"]').value = appointment.duration_minutes

    this.calculateItemTotal(newItem)
    this.calculateTotal()
  }

  clearAllItems() {
    const items = this.saleItemsContainerTarget.querySelectorAll('.sale-item-row')
    items.forEach(item => {
      const destroyField = item.querySelector('input[name*="[_destroy]"]')
      if (destroyField) {
        destroyField.value = '1'
        item.style.display = 'none'
      } else {
        item.remove()
      }
    })
  }

  calculateItemTotal(itemRow) {
    const quantityField = itemRow.querySelector('input[name*="[quantity]"]')
    const priceField = itemRow.querySelector('input[name*="[unit_price]"]')
    const totalField = itemRow.querySelector('input[name*="[total_price]"]')

    if (quantityField && priceField && totalField) {
      const quantity = parseFloat(quantityField.value) || 0
      const price = parseFloat(priceField.value) || 0
      const total = quantity * price

      totalField.value = total.toFixed(2)
    }
  }

  calculateTotal() {
    let total = 0
    const visibleItems = this.saleItemsContainerTarget.querySelectorAll('.sale-item-row:not([style*="display: none"])')

    visibleItems.forEach(item => {
      const totalField = item.querySelector('input[name*="[total_price]"]')
      if (totalField) {
        total += parseFloat(totalField.value) || 0
      }
    })

    if (this.hasTotalAmountTarget) {
      this.totalAmountTarget.textContent = `$${total.toFixed(2)}`
    }
  }

  updateItemFieldNames(container, index) {
    const fields = container.querySelectorAll('input, select, textarea')
    fields.forEach(field => {
      if (field.name) {
        field.name = field.name.replace(/\[\d*\]/, `[${index}]`)
      }
      if (field.id) {
        field.id = field.id.replace(/_\d*_/, `_${index}_`)
      }
    })
  }

  setupAutocomplete() {
    // Add basic autocomplete functionality for customer names
    if (this.hasCustomerNameTarget) {
      this.customerNameTarget.addEventListener('input', (event) => {
        this.handleCustomerNameInput(event)
      })
    }
  }

  handleCustomerNameInput(event) {
    const value = event.target.value.toLowerCase()
    const matches = this.customersValue.filter(customer =>
      `${customer.first_name} ${customer.last_name}`.toLowerCase().includes(value)
    )

    // You could implement a dropdown here for customer suggestions
    // For now, we'll just log the matches for debugging
    console.log('Customer matches:', matches)
  }
}
