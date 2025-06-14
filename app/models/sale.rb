# app/models/sale.rb
class Sale < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :customer
  belongs_to :staff_member # Customer service staff who processed the sale
  belongs_to :appointment, optional: true # Optional - for appointment-based sales
  has_many :sale_items, dependent: :destroy

  validates :sale_number, presence: true, uniqueness: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :customer_name, presence: true
  validates :sale_date, presence: true
  validates :sale_type, inclusion: { in: %w[appointment walk_in online phone] }
  validates :payment_status, inclusion: { in: %w[unpaid partial paid refunded] }
  validates :sale_status, inclusion: { in: %w[pending confirmed completed cancelled] }

  # Validate staff member role
  validate :staff_member_can_process_sales

  # Nested attributes for sale items
  accepts_nested_attributes_for :sale_items, allow_destroy: true, reject_if: :all_blank

  scope :this_month, -> { where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :this_week, -> { where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :today, -> { where(sale_date: Date.current.all_day) }
  scope :by_staff, ->(staff_id) { where(staff_member_id: staff_id) }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :appointment_based, -> { where.not(appointment_id: nil) }
  scope :walk_in, -> { where(sale_type: 'walk_in') }
  scope :paid, -> { where(payment_status: 'paid') }
  scope :unpaid, -> { where(payment_status: 'unpaid') }

  enum sale_type: { appointment: 0, walk_in: 1, online: 2, phone: 3 }
  enum payment_status: { unpaid: 0, partial: 1, paid: 2, refunded: 3 }
  enum sale_status: { pending: 0, confirmed: 1, completed: 2, cancelled: 3 }

  before_validation :generate_sale_number, on: :create
  before_save :calculate_totals
  after_create :sync_appointment_payment_status, if: :appointment_id?

  def staff_name
    staff_member.full_name
  end

  def remaining_balance
    total_amount - paid_amount
  end

  def payment_complete?
    paid? || paid_amount >= total_amount
  end

  def add_payment!(amount, method: nil, reference: nil)
    new_paid_amount = (paid_amount || 0) + amount

    update!(
      paid_amount: new_paid_amount,
      payment_method: method,
      payment_reference: reference,
      payment_received_at: Time.current,
      payment_status: determine_payment_status(new_paid_amount)
    )
  end

  def refund!(amount, reason: nil)
    return false if amount > paid_amount

    new_paid_amount = paid_amount - amount

    update!(
      paid_amount: new_paid_amount,
      payment_status: new_paid_amount > 0 ? 'partial' : 'unpaid',
      notes: [notes, "Refund: #{amount} - #{reason}"].compact.join("\n")
    )
  end

  # Quick methods to add common items
  def add_service_item!(name, price, duration: nil, service_tier: nil)
    sale_items.create!(
      tenant: tenant,
      item_type: 'service',
      name: name,
      quantity: 1,
      unit_price: price,
      total_price: price,
      duration_minutes: duration,
      service_tier: service_tier
    )
  end

  def add_product_item!(name, price, quantity: 1, sku: nil, category: nil)
    sale_items.create!(
      tenant: tenant,
      item_type: 'product',
      name: name,
      quantity: quantity,
      unit_price: price,
      total_price: price * quantity,
      sku: sku,
      product_category: category
    )
  end

  def add_addon_item!(name, price, description: nil)
    sale_items.create!(
      tenant: tenant,
      item_type: 'addon',
      name: name,
      description: description,
      quantity: 1,
      unit_price: price,
      total_price: price
    )
  end

  # Common preset items for passport photos, prints, etc.
  def self.add_passport_sale!(customer, staff_member, quantity: 2, price_per_set: 25.0)
    create!(
      tenant: ActsAsTenant.current_tenant,
      customer: customer,
      staff_member: staff_member,
      customer_name: customer.full_name,
      customer_email: customer.email,
      customer_phone: customer.phone,
      total_amount: price_per_set * quantity,
      sale_type: 'walk_in',
      sale_date: Time.current,
      sale_status: 'confirmed',
      notes: "Passport photos - quick service",
      sale_items_attributes: [
        {
          tenant: ActsAsTenant.current_tenant,
          item_type: 'product',
          name: 'Passport Photos',
          description: '2x2 inch passport photos, set of 4',
          quantity: quantity,
          unit_price: price_per_set,
          total_price: price_per_set * quantity,
          product_category: 'passport'
        }
      ]
    )
  end

  def self.total_revenue_for_period(start_date, end_date)
    where(sale_date: start_date..end_date)
      .where(sale_status: ['confirmed', 'completed'])
      .sum(:total_amount)
  end

  def self.staff_performance(start_date, end_date)
    joins(:staff_member)
      .where(sale_date: start_date..end_date)
      .where(sale_status: ['confirmed', 'completed'])
      .group('staff_members.first_name, staff_members.last_name, staff_members.id')
      .select('staff_members.id, staff_members.first_name, staff_members.last_name')
      .sum(:total_amount)
  end

  private

  def generate_sale_number
    return if sale_number.present?

    # Generate format: SALE-YYYYMMDD-#### (e.g., SALE-20250614-0001)
    date_prefix = Date.current.strftime("%Y%m%d")
    last_sale_today = Sale.where("sale_number LIKE ?", "SALE-#{date_prefix}-%")
                         .order(:sale_number)
                         .last

    if last_sale_today
      last_number = last_sale_today.sale_number.split('-').last.to_i
      new_number = (last_number + 1).to_s.rjust(4, '0')
    else
      new_number = '0001'
    end

    self.sale_number = "SALE-#{date_prefix}-#{new_number}"
  end

  def calculate_totals
    # Recalculate totals based on sale items
    items_total = sale_items.sum { |item| item.total_price || 0 }
    discount_total = sale_items.sum { |item| item.discount_amount || 0 }

    self.total_amount = items_total - discount_total + (tax_amount || 0)
  end

  def determine_payment_status(paid_amount)
    return 'unpaid' if paid_amount <= 0
    return 'paid' if paid_amount >= total_amount
    'partial'
  end

  def sync_appointment_payment_status
    return unless appointment

    appointment.update!(
      paid_amount: paid_amount,
      payment_status: payment_status,
      payment_received_at: payment_received_at,
      payment_method: payment_method,
      payment_reference: payment_reference
    )
  end

  def staff_member_can_process_sales
    unless staff_member.customer_service? || staff_member.role.in?(['manager', 'receptionist'])
      errors.add(:staff_member, "must be customer service, manager, or receptionist to process sales")
    end
  end
end
