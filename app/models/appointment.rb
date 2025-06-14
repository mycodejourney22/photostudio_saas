# app/models/appointment.rb (updated with staff assignments)
class Appointment < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :customer
  belongs_to :user # staff member who created the appointment
  belongs_to :studio, optional: true # keeping for backward compatibility
  belongs_to :studio_location, optional: true # new location-based system
  belongs_to :service_tier, optional: true # new package-based system
  belongs_to :booked_by_staff, class_name: 'StaffMember', optional: true

  # Staff assignments for production workflow
  # Check if we have assigned_photographer_id or photographer_id columns
  if column_names.include?('assigned_photographer_id')
    belongs_to :assigned_photographer, class_name: 'StaffMember', optional: true
  elsif column_names.include?('photographer_id')
    belongs_to :photographer, class_name: 'StaffMember', optional: true
    alias_attribute :assigned_photographer, :photographer
    alias_attribute :assigned_photographer_id, :photographer_id
  end

  if column_names.include?('assigned_editor_id')
    belongs_to :assigned_editor, class_name: 'StaffMember', optional: true
  elsif column_names.include?('editor_id')
    belongs_to :editor, class_name: 'StaffMember', optional: true
    alias_attribute :assigned_editor, :editor
    alias_attribute :assigned_editor_id, :editor_id
  end

  # Sale relationship (optional - appointment may generate a sale)
  has_one :sale, dependent: :nullify

  validates :scheduled_at, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :session_type, inclusion: { in: %w[portrait wedding family event commercial] }
  validates :status, inclusion: { in: %w[pending confirmed in_progress completed cancelled] }
  validates :payment_status, inclusion: { in: %w[unpaid partial_paid paid refunded] }
  validates :booking_source, inclusion: { in: %w[customer staff walk_in online] }

  # Validate staff assignments based on roles (only if columns exist)
  validate :photographer_must_be_photographer_role, if: -> { assigned_photographer.present? }
  validate :editor_must_be_editor_role, if: -> { assigned_editor.present? }

  scope :upcoming, -> { where(scheduled_at: Time.current..) }
  scope :today, -> { where(scheduled_at: Date.current.all_day) }
  scope :this_week, -> { where(scheduled_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :current_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }

  # Dynamic scopes based on available columns
  if column_names.include?('assigned_photographer_id') || column_names.include?('photographer_id')
    scope :with_photographer, ->(photographer_id) {
      column = column_names.include?('assigned_photographer_id') ? 'assigned_photographer_id' : 'photographer_id'
      where(column => photographer_id)
    }
    scope :needs_photographer, -> {
      column = column_names.include?('assigned_photographer_id') ? 'assigned_photographer_id' : 'photographer_id'
      where(column => nil)
    }
  end

  if column_names.include?('assigned_editor_id') || column_names.include?('editor_id')
    scope :with_editor, ->(editor_id) {
      column = column_names.include?('assigned_editor_id') ? 'assigned_editor_id' : 'editor_id'
      where(column => editor_id)
    }
    scope :needs_editor, -> {
      column = column_names.include?('assigned_editor_id') ? 'assigned_editor_id' : 'editor_id'
      where(column => nil)
    }
  end

  if column_names.include?('shoot_completed_at')
    scope :shoot_completed, -> { where.not(shoot_completed_at: nil) }
  end

  if column_names.include?('editing_completed_at')
    scope :editing_completed, -> { where.not(editing_completed_at: nil) }
  end

  enum status: { pending: 0, confirmed: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum session_type: { portrait: 0, wedding: 1, family: 2, event: 3, commercial: 4 }
  enum payment_status: { unpaid: 0, partial_paid: 1, paid: 2, refunded: 3 }
  enum booking_source: { customer: 0, staff: 1, walk_in: 2, online: 3 }

  before_save :calculate_end_time, :sync_service_tier_data
  after_update :send_status_notification, if: :saved_change_to_status?

  def end_time
    scheduled_at + duration_minutes.minutes
  end

  def can_be_cancelled?
    pending? || confirmed?
  end

  def revenue_impact
    completed? ? price : 0
  end

  def service_package
    service_tier&.service_package
  end

  def service_package_name
    service_package&.name || session_type&.humanize
  end

  def service_tier_name
    service_tier&.name || 'Custom'
  end

  def location_name
    studio_location&.name || studio&.name || 'TBD'
  end

  def total_amount
    price + (deposit_amount || 0)
  end

  def remaining_balance
    total_amount - (paid_amount || 0)
  end

  def payment_complete?
    paid? || (paid_amount && paid_amount >= total_amount)
  end

  def requires_deposit?
    deposit_amount.present?
  end

  # Production workflow methods
  def photographer_name
    assigned_photographer&.full_name || 'Not assigned'
  end

  def editor_name
    assigned_editor&.full_name || 'Not assigned'
  end

  def shoot_completed?
    respond_to?(:shoot_completed_at) && shoot_completed_at.present?
  end

  def editing_completed?
    respond_to?(:editing_completed_at) && editing_completed_at.present?
  end

  def production_complete?
    shoot_completed? && editing_completed?
  end

  def days_until_delivery
    return nil unless respond_to?(:delivery_date) && delivery_date
    (delivery_date - Date.current).to_i
  end

  def overdue_delivery?
    respond_to?(:delivery_date) && delivery_date && delivery_date < Date.current
  end

  def mark_shoot_completed!(completed_at = Time.current)
    if respond_to?(:shoot_completed_at=)
      update!(shoot_completed_at: completed_at)
    else
      raise "shoot_completed_at column not available"
    end
  end

  def mark_editing_completed!(completed_at = Time.current)
    if respond_to?(:editing_completed_at=)
      update!(editing_completed_at: completed_at)
    else
      raise "editing_completed_at column not available"
    end
  end

  def assign_photographer!(staff_member)
    raise ArgumentError, "Staff member must be a photographer" unless staff_member.photographer?

    if respond_to?(:assigned_photographer=)
      update!(assigned_photographer: staff_member)
    elsif respond_to?(:photographer=)
      update!(photographer: staff_member)
    else
      raise "No photographer assignment column available"
    end
  end

  def assign_editor!(staff_member)
    raise ArgumentError, "Staff member must be an editor" unless staff_member.editor?

    if respond_to?(:assigned_editor=)
      update!(assigned_editor: staff_member)
    elsif respond_to?(:editor=)
      update!(editor: staff_member)
    else
      raise "No editor assignment column available"
    end
  end

  # Generate a sale for this appointment
  def create_sale!(staff_member, additional_items: [])
    return sale if sale.present?

    Sale.create!(
      tenant: tenant,
      appointment: self,
      customer: customer,
      staff_member: staff_member,
      customer_name: customer.full_name,
      customer_email: customer.email,
      customer_phone: customer.phone,
      total_amount: price,
      sale_type: 'appointment',
      sale_date: Time.current,
      sale_status: 'confirmed',
      payment_status: payment_status == 'paid' ? 'paid' : 'unpaid',
      paid_amount: paid_amount || 0,
      notes: "Generated from appointment ##{id}",
      sale_items_attributes: [
        {
          tenant: tenant,
          item_type: 'service',
          name: service_package_name,
          description: "#{session_type.humanize} session - #{duration_minutes} minutes",
          quantity: 1,
          unit_price: price,
          total_price: price,
          duration_minutes: duration_minutes,
          service_tier: service_tier
        }
      ] + additional_items
    )
  end

  private

  def calculate_end_time
    # This method can be used for calendar integration
  end

  def sync_service_tier_data
    # Sync data from service tier if needed
  end

  def send_status_notification
    # Send notifications when status changes
  end

  def photographer_must_be_photographer_role
    unless assigned_photographer.photographer?
      errors.add(:assigned_photographer, "must be a photographer")
    end
  end

  def editor_must_be_editor_role
    unless assigned_editor.editor?
      errors.add(:assigned_editor, "must be an editor")
    end
  end
end
