# app/models/sale.rb (Enhanced version)
class Sale < ApplicationRecord
  acts_as_tenant :tenant

  # Virtual attributes to skip validations when needed
  attr_accessor :skip_item_validation, :skip_amount_validation

  belongs_to :customer
  belongs_to :staff_member
  belongs_to :appointment, optional: true
  has_many :sale_items, dependent: :destroy

  validates :sale_number, presence: true, uniqueness: { scope: :tenant_id }
  validates :total_amount, presence: true, numericality: { greater_than: 0 }, on: :create, unless: :skip_total_validation?
  validates :customer_name, presence: true
  validates :sale_date, presence: true
  validates :sale_type, inclusion: { in: %w[appointment walk_in online phone] }
  validates :payment_status, inclusion: { in: %w[unpaid partial paid refunded] }
  validates :sale_status, inclusion: { in: %w[pending confirmed completed cancelled] }

  validate :staff_member_can_process_sales
  validate :appointment_belongs_to_same_tenant, if: :appointment_id?
  validate :customer_belongs_to_same_tenant, if: :customer_id?
  validate :at_least_one_sale_item, unless: :skip_item_validation

  accepts_nested_attributes_for :sale_items, allow_destroy: true, reject_if: :all_blank

  # Scopes
  scope :this_month, -> { where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :this_week, -> { where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :today, -> { where(sale_date: Date.current.all_day) }
  scope :by_staff, ->(staff_id) { where(staff_member_id: staff_id) }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :appointment_based, -> { where.not(appointment_id: nil) }
  scope :walk_in, -> { where(sale_type: 'walk_in') }
  scope :paid, -> { where(payment_status: 'paid') }
  scope :unpaid, -> { where(payment_status: 'unpaid') }
  scope :recent, -> { order(created_at: :desc) }

  enum sale_type: { appointment: 0, walk_in: 1, online: 2, phone: 3 }
  enum payment_status: { unpaid: 0, partial: 1, paid: 2, refunded: 3 }
  enum sale_status: { pending: 0, confirmed: 1, completed: 2, cancelled: 3 }

  before_validation :generate_sale_number, on: :create
  before_validation :set_default_values, on: :create
  before_validation :set_customer_info_from_appointment, if: :appointment_id?
  before_validation :auto_set_payment_info, on: :create
  before_save :calculate_totals
  after_create :sync_appointment_payment_status, if: :appointment_id?
  after_update :sync_appointment_payment_status, if: :appointment_id?

  # Instance methods
  def staff_name
    staff_member&.full_name || 'Unknown Staff'
  end

  def customer_display_name
    customer&.full_name || customer_name
  end

  def remaining_balance
    total_amount - (paid_amount || 0)
  end

  def payment_complete?
    paid? || (paid_amount.present? && paid_amount >= total_amount)
  end

  def can_be_deleted?
    pending? && (paid_amount.nil? || paid_amount.zero?)
  end

  def can_be_refunded?
    paid? && paid_amount.present? && paid_amount > 0
  end

  def service_items
    sale_items.where(item_type: 'service')
  end

  def product_items
    sale_items.where(item_type: 'product')
  end

  def package_items
    sale_items.where(item_type: 'package')
  end

  def total_duration
    sale_items.sum(:duration_minutes) || 0
  end

  def add_payment!(amount, method: nil, reference: nil, notes: nil)
    raise ArgumentError, "Amount must be positive" if amount <= 0
    raise ArgumentError, "Payment exceeds remaining balance" if amount > remaining_balance

    new_paid_amount = (paid_amount || 0) + amount

    update!(
      paid_amount: new_paid_amount,
      payment_method: method || payment_method,
      payment_reference: reference || payment_reference,
      payment_received_at: Time.current,
      payment_status: determine_payment_status(new_paid_amount),
      notes: notes.present? ? [self.notes, notes].compact.join("\n") : self.notes
    )

    # Update appointment payment status if linked
    appointment&.update_payment_status_from_sale!

    true
  end

  def refund!(amount, reason: nil)
    raise ArgumentError, "Amount must be positive" if amount <= 0
    raise ArgumentError, "Refund amount exceeds paid amount" if amount > (paid_amount || 0)

    new_paid_amount = (paid_amount || 0) - amount
    refund_note = "Refund: $#{amount}"
    refund_note += " - #{reason}" if reason.present?

    update!(
      paid_amount: new_paid_amount,
      payment_status: determine_payment_status(new_paid_amount),
      notes: [notes, refund_note].compact.join("\n")
    )

    # Update appointment payment status if linked
    appointment&.update_payment_status_from_sale!

    true
  end

  # Quick methods to add common items
  def add_service_item!(name, price, duration: nil, service_tier: nil, description: nil)
    sale_items.create!(
      item_type: 'service',
      name: name,
      description: description || "#{name} service",
      quantity: 1,
      unit_price: price,
      total_price: price,
      duration_minutes: duration,
      service_tier: service_tier
    )
  end

  def add_product_item!(name, price, quantity: 1, sku: nil, category: nil)
    sale_items.create!(
      item_type: 'product',
      name: name,
      quantity: quantity,
      unit_price: price,
      total_price: price * quantity,
      sku: sku,
      product_category: category
    )
  end

  def add_package_item!(name, price, services: [], description: nil)
    item = sale_items.create!(
      item_type: 'package',
      name: name,
      description: description || "#{name} package",
      quantity: 1,
      unit_price: price,
      total_price: price
    )

    # Store package contents in metadata
    if services.any?
      item.update!(metadata: { included_services: services })
    end

    item
  end

  # Duplicate this sale for a new customer
  def duplicate_for_new_customer
    new_sale = self.dup
    new_sale.sale_number = nil
    new_sale.customer_id = nil
    new_sale.customer_name = nil
    new_sale.customer_email = nil
    new_sale.customer_phone = nil
    new_sale.appointment_id = nil
    new_sale.sale_date = Time.current
    new_sale.payment_status = 'unpaid'
    new_sale.paid_amount = 0
    new_sale.payment_received_at = nil
    new_sale.payment_reference = nil

    # Duplicate sale items
    sale_items.each do |item|
      new_item = item.dup
      new_sale.sale_items << new_item
    end

    new_sale
  end

  # Class methods
  def self.create_from_appointment!(appointment, staff_member)
    sale = appointment.tenant.sales.build(
      appointment: appointment,
      customer: appointment.customer,
      staff_member: staff_member,
      customer_name: appointment.customer.full_name,
      customer_email: appointment.customer.email,
      customer_phone: appointment.customer.phone,
      sale_type: 'appointment',
      sale_date: Time.current,
      sale_status: 'confirmed'
    )

    # Add the appointment service
    sale.sale_items.build(
      item_type: 'service',
      name: appointment.service_package_name,
      description: "#{appointment.session_type.humanize} session",
      quantity: 1,
      unit_price: appointment.price,
      total_price: appointment.price,
      duration_minutes: appointment.duration_minutes,
      service_tier: appointment.service_tier
    )

    sale.save!
    appointment.update!(sale: sale)
    sale
  end

  def self.create_passport_sale!(customer, staff_member, quantity: 1)
    sale = customer.tenant.sales.create!(
      customer: customer,
      staff_member: staff_member,
      customer_name: customer.full_name,
      customer_email: customer.email,
      customer_phone: customer.phone,
      sale_type: 'walk_in',
      sale_date: Time.current,
      sale_status: 'confirmed'
    )

    sale.add_product_item!('Passport Photos', 15.0, quantity: quantity, category: 'photos')
    sale
  end

  def self.revenue_stats(period = :month)
    case period
    when :today
      where(sale_date: Date.current.all_day)
    when :week
      where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week)
    when :month
      where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month)
    when :year
      where(sale_date: Date.current.beginning_of_year..Date.current.end_of_year)
    else
      all
    end.group(:payment_status).sum(:total_amount)
  end

  private

  def generate_sale_number
    return if sale_number.present?

    loop do
      # Generate format: S2024001234
      year = Date.current.year
      sequence = tenant.sales.where('created_at >= ?', Date.current.beginning_of_year).count + 1
      self.sale_number = "S#{year}#{sequence.to_s.rjust(6, '0')}"

      break unless self.class.exists?(sale_number: sale_number, tenant_id: tenant_id)
    end
  end

  def set_default_values
    self.sale_date ||= Time.current
    self.sale_status ||= 'pending'
    self.payment_status ||= 'unpaid'
    self.paid_amount ||= 0
    self.total_amount ||= 0
  end

  def set_customer_info_from_appointment
    if appointment.present?
      self.customer ||= appointment.customer
      self.customer_name = appointment.customer.full_name
      self.customer_email = appointment.customer.email
      self.customer_phone = appointment.customer.phone
      self.sale_type = 'appointment'
    end
  end

  def auto_set_payment_info
    # Skip if this is a draft
    return if sale_status == 'pending' && payment_status == 'unpaid'

    # Skip if payment info is explicitly set to unpaid or partial
    return if payment_status == 'unpaid' || payment_status == 'partial'

    # Auto-pay logic based on payment status and method
    case payment_status
    when 'paid'
      auto_mark_as_paid
    when 'partial'
      # Keep the paid_amount as set in the form
      self.payment_received_at = Time.current if paid_amount.present? && paid_amount > 0
    else
      # Default behavior based on payment method
      if should_auto_pay_based_on_method?
        auto_mark_as_paid
      else
        # Mark as unpaid (invoice style)
        self.paid_amount ||= 0
        self.payment_status = 'unpaid'
      end
    end
  end

  private

  def should_auto_pay_based_on_method?
    # Auto-pay for immediate payment methods
    ['cash', 'credit_card', 'debit_card'].include?(payment_method)
  end

  def auto_mark_as_paid
    # Calculate total first to ensure we have the right amount
    calculate_totals if total_amount.blank? || total_amount.zero?

    self.paid_amount = total_amount
    self.payment_status = 'paid'
    self.payment_received_at = Time.current
  end

  def calculate_totals
    # Skip calculation if no sale items
    return if sale_items.empty?

    # Calculate subtotal from all items that aren't marked for destruction
    valid_items = sale_items.reject(&:marked_for_destruction?)
    return if valid_items.empty?

    subtotal = valid_items.sum do |item|
      quantity = item.quantity.present? ? item.quantity.to_f : 0
      price = item.unit_price.present? ? item.unit_price.to_f : 0
      quantity * price
    end

    # Calculate total discount
    total_discount = valid_items.sum { |item| (item.discount_amount || 0).to_f }

    # Update totals
    self.discount_amount = total_discount
    self.total_amount = subtotal - total_discount + (tax_amount || 0).to_f

    # Ensure total_amount is at least 0
    self.total_amount = [self.total_amount, 0].max

    # Only auto-update payment status if it wasn't explicitly set and we have payments
    if total_amount_changed? && should_auto_update_payment_status?
      self.payment_status = determine_payment_status(paid_amount || 0)
    end
  end

  def should_auto_update_payment_status?
    # Don't auto-update if payment status was manually set in form
    # Only auto-update if there are actual payments or it's currently unpaid
    (paid_amount.present? && paid_amount > 0) || payment_status == 'unpaid'
  end

  def at_least_one_sale_item
    if sale_items.reject(&:marked_for_destruction?).empty?
      errors.add(:sale_items, "must have at least one item")
    end
  end

  def skip_total_validation?
    # Skip validation if it's a draft or if we're in the middle of building the sale
    sale_status == 'pending' || skip_amount_validation || total_amount.blank?
  end

  def determine_payment_status(amount)
    return 'unpaid' if amount.zero?
    return 'paid' if amount >= total_amount
    'partial'
  end

  def staff_member_can_process_sales
    return unless staff_member

    unless staff_member.can_process_sales?
      errors.add(:staff_member, "must be customer service, manager, or owner to process sales")
    end
  end

  def appointment_belongs_to_same_tenant
    return unless appointment

    unless appointment.tenant_id == tenant_id
      errors.add(:appointment, "must belong to the same tenant")
    end
  end

  def customer_belongs_to_same_tenant
    return unless customer

    unless customer.tenant_id == tenant_id
      errors.add(:customer, "must belong to the same tenant")
    end
  end

  def sync_appointment_payment_status
    return unless appointment

    # Update appointment payment status based on sale payment status
    case payment_status
    when 'paid'
      appointment.update_column(:payment_status, 'paid')
    when 'partial'
      appointment.update_column(:payment_status, 'partial')
    else
      appointment.update_column(:payment_status, 'unpaid')
    end
  end
end
