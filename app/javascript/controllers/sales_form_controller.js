// app/javascript/controllers/sales_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "saleItemsList",
    "noItemsMessage",
    "appointmentField",
    "customerName",
    "customerEmail",
    "customerPhone",
    "subtotalAmount",
    "discountAmount",
    "totalAmount",
    "paidAmount",
    "paymentStatusDisplay",
    "paymentStatusText",
    "balanceLeft"
  ]

  static values = {
    itemIndex: Number,
    serviceTiers: Array,
    customers: Array
  }

  connect() {
    this.itemIndexValue = this.saleItemsListTarget.children.length
    this.updateTotals()
    this.updatePaymentStatus()
  }

  addSaleItem() {
    const newItemHtml = this.buildSaleItemHTML(this.itemIndexValue)
    this.saleItemsListTarget.insertAdjacentHTML('beforeend', newItemHtml)
    this.noItemsMessageTarget.style.display = 'none'
    this.itemIndexValue++
    this.updateTotals()
  }

  removeSaleItem(event) {
    const itemRow = event.target.closest('.sale-item-row')
    const destroyField = itemRow.querySelector('.destroy-field')

    if (destroyField.name.includes('new_')) {
      // Remove new item completely
      itemRow.remove()
    } else {
      // Mark existing item for destruction
      destroyField.value = 'true'
      itemRow.style.display = 'none'
    }

    this.updateTotals()

    // Show no items message if no visible items
    const visibleItems = this.saleItemsListTarget.querySelectorAll('.sale-item-row:not([style*="display: none"])')
    if (visibleItems.length === 0) {
      this.noItemsMessageTarget.style.display = 'block'
    }
  }

  addQuickItem(event) {
    const itemType = event.params.itemType
    this.addSaleItem()

    const lastItem = this.saleItemsListTarget.querySelector('.sale-item-row:last-child')
    const nameField = lastItem.querySelector('input[name*="[name]"]')
    const priceField = lastItem.querySelector('input[name*="[unit_price]"]')
    const typeField = lastItem.querySelector('select[name*="[item_type]"]')
    const categoryField = lastItem.querySelector('select[name*="[product_category]"]')

    const quickItems = {
      passport: { name: 'Passport Photos', price: '25.00', type: 'product', category: 'passport' },
      prints: { name: '4x6 Prints', price: '15.00', type: 'product', category: 'prints' },
      digital: { name: 'Digital Gallery Access', price: '50.00', type: 'product', category: 'digital' },
      rush: { name: 'Rush Service', price: '75.00', type: 'addon', category: null }
    }

    const item = quickItems[itemType]
    if (item) {
      nameField.value = item.name
      priceField.value = item.price
      typeField.value = item.type
      if (categoryField && item.category) categoryField.value = item.category

      this.updateItemType({ target: typeField })
      this.calculateItemTotal({ target: priceField })
    }
  }

  calculateItemTotal(event) {
    const itemRow = event.target.closest('.sale-item-row')
    const quantity = parseFloat(itemRow.querySelector('input[name*="[quantity]"]').value) || 0
    const unitPrice = parseFloat(itemRow.querySelector('input[name*="[unit_price]"]').value) || 0
    const totalField = itemRow.querySelector('input[name*="[total_price]"]')

    const total = quantity * unitPrice
    totalField.value = total.toFixed(2)

    this.updateTotals()
  }

  updateTotals() {
    let subtotal = 0
    let discountTotal = 0

    // Calculate subtotal from all visible sale items
    const items = this.saleItemsListTarget.querySelectorAll('.sale-item-row:not([style*="display: none"])')
    items.forEach(item => {
      const totalField = item.querySelector('.item-total')
      if (totalField && totalField.value) {
        const itemTotal = parseFloat(totalField.value) || 0
        const itemType = item.querySelector('select[name*="[item_type]"]').value

        if (itemType === 'discount') {
          discountTotal += itemTotal
        } else {
          subtotal += itemTotal
        }
      }
    })

    const total = subtotal - discountTotal

    // Update display
    this.subtotalAmountTarget.textContent = `${subtotal.toFixed(2)}`
    this.discountAmountTarget.textContent = `${discountTotal.toFixed(2)}`
    this.totalAmountTarget.textContent = `${total.toFixed(2)}`

    // Auto-set paid amount to total if it's currently empty or zero
    if (!this.paidAmountTarget.value || parseFloat(this.paidAmountTarget.value) === 0) {
      this.paidAmountTarget.value = total.toFixed(2)
    }

    // Update payment status after totals change
    this.updatePaymentStatus()
  }

  updatePaymentStatus() {
    const totalAmount = parseFloat(this.totalAmountTarget.textContent.replace(/,/g, '')) || 0
    const paidAmount = parseFloat(this.paidAmountTarget.value) || 0
    const balanceLeft = Math.max(0, totalAmount - paidAmount)

    let status = 'unpaid'
    let statusClass = 'bg-red-50 border-red-200 text-red-800'

    if (paidAmount > 0) {
      if (paidAmount >= totalAmount) {
        status = 'paid'
        statusClass = 'bg-green-50 border-green-200 text-green-800'
      } else {
        status = 'partial'
        statusClass = 'bg-yellow-50 border-yellow-200 text-yellow-800'
      }
    }

    // Update payment status display
    this.paymentStatusDisplayTarget.className = `px-3 py-2 border rounded-md text-sm ${statusClass}`
    this.paymentStatusTextTarget.textContent = `${status.charAt(0).toUpperCase() + status.slice(1)} - ${paidAmount.toFixed(2)} of ${totalAmount.toFixed(2)}`

    // Update balance left display
    if (this.hasBalanceLeftTarget) {
      this.balanceLeftTarget.textContent = `${balanceLeft.toFixed(2)}`

      // Show/hide balance based on whether there's a remaining balance
      const balanceRow = this.balanceLeftTarget.closest('.balance-row')
      if (balanceRow) {
        balanceRow.style.display = balanceLeft > 0 ? 'flex' : 'none'
      }
    }
  }

  updateItemType(event) {
    const itemRow = event.target.closest('.sale-item-row')
    const serviceTierField = itemRow.querySelector('.service-tier-field')
    const productCategoryField = itemRow.querySelector('.product-category-field')

    if (serviceTierField) {
      serviceTierField.style.display = event.target.value === 'service' ? 'block' : 'none'
    }

    if (productCategoryField) {
      productCategoryField.style.display = event.target.value === 'product' ? 'block' : 'none'
    }
  }

  updateCustomerInfo(event) {
    const customerId = event.target.value

    if (!customerId) return

    // Get the selected customer name and update manual fields
    const selectedOption = event.target.options[event.target.selectedIndex]
    if (this.hasCustomerNameTarget) {
      this.customerNameTarget.value = selectedOption.text
    }

    // You could implement AJAX to fetch customer details here
    // fetch(`/customers/${customerId}.json`)
    //   .then(response => response.json())
    //   .then(data => {
    //     this.customerEmailTarget.value = data.email || ''
    //     this.customerPhoneTarget.value = data.phone || ''
    //   })
  }

  toggleAppointmentField(event) {
    if (this.hasAppointmentFieldTarget) {
      this.appointmentFieldTarget.style.display = event.target.value === 'appointment' ? 'block' : 'none'
    }
  }

  buildSaleItemHTML(index) {
    return `
      <div class="sale-item-row bg-gray-50 p-4 rounded-lg mb-4">
        <div class="grid grid-cols-1 md:grid-cols-6 gap-4 items-end">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Type</label>
            <select name="sale[sale_items_attributes][${index}][item_type]"
                    class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    data-action="change->sales-form#updateItemType">
              <option value="service">Service</option>
              <option value="product">Product</option>
              <option value="addon">Add-on</option>
              <option value="discount">Discount</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Item Name</label>
            <input type="text" name="sale[sale_items_attributes][${index}][name]"
                   class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                   placeholder="Item name">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Qty</label>
            <input type="number" name="sale[sale_items_attributes][${index}][quantity]"
                   value="1" min="1"
                   class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                   data-action="change->sales-form#calculateItemTotal">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Unit Price</label>
            <input type="number" name="sale[sale_items_attributes][${index}][unit_price]"
                   step="0.01" min="0"
                   class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                   data-action="change->sales-form#calculateItemTotal">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Total</label>
            <input type="number" name="sale[sale_items_attributes][${index}][total_price]"
                   step="0.01" readonly
                   class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm bg-gray-100 focus:outline-none focus:ring-blue-500 focus:border-blue-500 item-total">
          </div>
          <div>
            <button type="button"
                    data-action="click->sales-form#removeSaleItem"
                    class="w-full px-3 py-2 bg-red-100 text-red-700 text-sm font-medium rounded-md hover:bg-red-200 transition-colors">
              Remove
            </button>
            <input type="hidden" name="sale[sale_items_attributes][${index}][_destroy]" value="false" class="destroy-field">
          </div>
        </div>

        <!-- Service Tier (for services) -->
        <div class="service-tier-field mt-4" style="display: none;">
          <label class="block text-sm font-medium text-gray-700 mb-2">Service Package</label>
          <select name="sale[sale_items_attributes][${index}][service_tier_id]"
                  class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500">
            <option value="">Select Service Package</option>
            ${this.buildServiceTierOptions()}
          </select>
        </div>

        <!-- Product Category (for products) -->
        <div class="product-category-field mt-4" style="display: none;">
          <label class="block text-sm font-medium text-gray-700 mb-2">Product Category</label>
          <select name="sale[sale_items_attributes][${index}][product_category]"
                  class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500">
            <option value="">Select category...</option>
            <option value="passport">Passport Photos</option>
            <option value="prints">Prints</option>
            <option value="frames">Frames</option>
            <option value="albums">Albums</option>
            <option value="digital">Digital Products</option>
            <option value="canvas">Canvas Prints</option>
            <option value="metal_prints">Metal Prints</option>
            <option value="photo_books">Photo Books</option>
            <option value="accessories">Accessories</option>
            <option value="gift_cards">Gift Cards</option>
            <option value="other">Other</option>
          </select>
        </div>

        <div class="mt-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">Description (optional)</label>
          <textarea name="sale[sale_items_attributes][${index}][description]" rows="2"
                    class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Item description or details..."></textarea>
        </div>
      </div>
    `
  }

  buildServiceTierOptions() {
    // This would need to be populated from Rails data
    // You can pass service tiers as a data value from Rails
    return '' // Implement based on your service tiers data
  }
}
