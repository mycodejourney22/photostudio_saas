# app/models/appointment.rb (updated for service packages)
class Appointment < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :customer
  belongs_to :user # staff member who created the appointment
  belongs_to :studio, optional: true # keeping for backward compatibility
  belongs_to :studio_location, optional: true # new location-based system
  belongs_to :service_tier, optional: true # new package-based system
  belongs_to :booked_by_staff, class_name: 'StaffMember', optional: true

  # has_many :appointment_photos, dependent: :destroy
  # has_many :photos, through: :appointment_photos

  validates :scheduled_at, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :session_type, inclusion: { in: %w[portrait wedding family event commercial] }
  validates :status, inclusion: { in: %w[pending confirmed in_progress completed cancelled] }
  validates :payment_status, inclusion: { in: %w[unpaid partial_paid paid refunded] }
  validates :booking_source, inclusion: { in: %w[customer staff walk_in online] }

  scope :upcoming, -> { where(scheduled_at: Time.current..) }
  scope :today, -> { where(scheduled_at: Date.current.all_day) }
  scope :this_week, -> { where(scheduled_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :current_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }

  enum status: { pending: 0, confirmed: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum session_type: { portrait: 0, wedding: 1, family: 2, event: 3, commercial: 4 }
  # enum payment_status: { unpaid: 0, partial_paid: 1, paid: 2, refunded: 3 }
  # enum booking_source: { customer: 0, staff: 1, walk_in: 2, online: 3 }

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
    deposit_amount.present? && deposit_amount > 0
  end

  private

  def calculate_end_time
    # Additional business logic for scheduling
  end

  def sync_service_tier_data
    return unless service_tier

    # Sync data from service tier if not manually overridden
    self.duration_minutes = service_tier.duration_minutes if duration_minutes.blank?
    self.price = service_tier.price if price.blank?
    self.session_type = service_tier.service_package.category if session_type.blank?
  end

  def send_status_notification
    AppointmentStatusJob.perform_async(id)
  end
end
