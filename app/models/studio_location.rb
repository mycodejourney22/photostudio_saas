# app/models/studio_location.rb
class StudioLocation < ApplicationRecord
  acts_as_tenant :tenant

  has_many :service_package_studio_locations, dependent: :destroy
  has_many :service_packages, through: :service_package_studio_locations
  has_many :appointments, dependent: :restrict_with_error
  has_many :expenses, dependent: :restrict_with_error
  before_validation :build_default_operating_hours, on: :create




  # validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true, length: { maximum: 100 }
  validates :default_slot_duration, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 480 } # max 8 hours

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  scope :recent, -> { order(created_at: :desc) }
  scope :ordered, -> { order(:sort_order, :name) }

  def full_address
    [address, city, state, postal_code].compact.join(', ')
  end

  def available_packages
    service_packages.joins(:service_package_studio_locations)
                   .where(service_package_studio_locations: { active: true })
                   .where(active: true)
                   .ordered
  end

  def can_be_deleted?
    !has_appointments?
  end

  def has_appointments?
    appointments.exists? if respond_to?(:appointments)
  end

   def has_expenses?
    expenses.exists?
  end

  def total_expenses_this_month
    expenses.this_month.sum(:amount)
  end

  def total_expenses_this_year
    expenses.this_year.sum(:amount)
  end

  def recent_expenses(limit = 5)
    expenses.recent.limit(limit)
  end

  def operating_hours_for_day(day)
    operating_hours[day.to_s] || { 'start' => '', 'end' => '' }
  end

  def open_on_day?(day)
    hours = operating_hours_for_day(day)
    hours['start'].present? && hours['end'].present?
  end

  def build_default_operating_hours
    if operating_hours.blank? || operating_hours == {}
      self.operating_hours = {
        'monday'    => { 'start' => '09:00', 'end' => '17:00' },
        'tuesday'   => { 'start' => '09:00', 'end' => '17:00' },
        'wednesday' => { 'start' => '09:00', 'end' => '17:00' },
        'thursday'  => { 'start' => '09:00', 'end' => '17:00' },
        'friday'    => { 'start' => '09:00', 'end' => '17:00' },
        'saturday'  => { 'start' => '10:00', 'end' => '16:00' },
        'sunday'    => { 'start' => '', 'end' => '' }
      }
    end
  end
    

  def booking_buffer_minutes
    booking_settings['buffer_time'] || 15
  end

  def advance_booking_days
    booking_settings['advance_booking_days'] || 30
  end

  def max_daily_bookings
    booking_settings.dig('max_daily_bookings') || 10
  end
end
