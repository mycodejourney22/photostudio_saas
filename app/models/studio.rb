class Studio < ApplicationRecord
  acts_as_tenant :tenant

  has_many :appointments, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :location, presence: true
  validates :capacity, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :available_at, ->(start_time, end_time) {
    where.not(
      id: Appointment.where(
        scheduled_at: start_time..end_time,
        status: ['confirmed', 'in_progress']
      ).select(:studio_id)
    )
  }

  def available_at?(start_time, end_time)
    !appointments.where(
      scheduled_at: start_time..end_time,
      status: ['confirmed', 'in_progress']
    ).exists?
  end

  def utilization_rate(period = 1.month.ago..Time.current)
    total_hours = appointments.where(created_at: period).sum(:duration_minutes) / 60.0
    available_hours = period.count / 1.hour * 8 # Assuming 8 working hours per day
    (total_hours / available_hours * 100).round(2)
  end
end
