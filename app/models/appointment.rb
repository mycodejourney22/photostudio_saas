class Appointment < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :customer
  belongs_to :user # staff member
  belongs_to :studio, optional: true

  # has_many :appointment_photos, dependent: :destroy
  # has_many :photos, through: :appointment_photos

  validates :scheduled_at, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :session_type, inclusion: { in: %w[portrait wedding family event commercial] }
  validates :status, inclusion: { in: %w[pending confirmed in_progress completed cancelled] }

  scope :upcoming, -> { where(scheduled_at: Time.current..) }
  scope :today, -> { where(scheduled_at: Date.current.all_day) }
  scope :this_week, -> { where(scheduled_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :current_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }

  enum status: { pending: 0, confirmed: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum session_type: { portrait: 0, wedding: 1, family: 2, event: 3, commercial: 4 }

  before_save :calculate_end_time
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

  private

  def calculate_end_time
    # Additional business logic for scheduling
  end

  def send_status_notification
    AppointmentStatusJob.perform_async(id)
  end
end
