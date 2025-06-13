# app/models/studio_location.rb
class StudioLocation < ApplicationRecord
  acts_as_tenant :tenant

  # has_many :service_package_studio_locations, dependent: :destroy
  # has_many :service_packages, through: :service_package_studio_locations
  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :default_slot_duration, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 480 } # max 8 hours

  scope :active, -> { where(active: true) }
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

  def operating_hours_for_day(day)
    return {} unless operating_hours.is_a?(Hash)
    operating_hours[day.to_s.downcase] || {}
  end

  def open_on_day?(day)
    hours = operating_hours_for_day(day)
    hours['start'].present? && hours['end'].present?
  end

  def default_operating_hours
    {
      'monday' => { 'start' => '09:00', 'end' => '17:00' },
      'tuesday' => { 'start' => '09:00', 'end' => '17:00' },
      'wednesday' => { 'start' => '09:00', 'end' => '17:00' },
      'thursday' => { 'start' => '09:00', 'end' => '17:00' },
      'friday' => { 'start' => '09:00', 'end' => '17:00' },
      'saturday' => { 'start' => '10:00', 'end' => '16:00' },
      'sunday' => { 'start' => '', 'end' => '' } # closed
    }
  end

  def booking_buffer_minutes
    booking_settings.dig('buffer_time') || 15
  end

  def advance_booking_days
    booking_settings.dig('advance_booking_days') || 30
  end

  def max_daily_bookings
    booking_settings.dig('max_daily_bookings') || 10
  end
end
