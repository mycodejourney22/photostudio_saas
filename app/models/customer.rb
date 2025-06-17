class Customer < ApplicationRecord
  acts_as_tenant :tenant

  has_many :appointments, dependent: :destroy
  # has_many :customer_photos, dependent: :destroy

  has_one_attached :profile_image
  has_many :sales, dependent: :destroy

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]{7,15}\z/ }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :with_recent_bookings, -> { joins(:appointments).where(appointments: { created_at: 1.month.ago.. }) }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def total_bookings
    appointments.count
  end

  def total_revenue
    appointments.completed.sum(:price)
  end

  def last_appointment
    appointments.order(:scheduled_at).last
  end
end
