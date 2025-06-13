# app/models/staff_member.rb
class StaffMember < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :user, optional: true # Only for staff who have login access
  has_many :appointments_as_photographer, class_name: 'Appointment', foreign_key: 'photographer_id'
  has_many :photoshoot_sessions_as_photographer, class_name: 'PhotoshootSession', foreign_key: 'photographer_id'
  has_many :photoshoot_sessions_as_editor, class_name: 'PhotoshootSession', foreign_key: 'editor_id'

  validates :first_name, :last_name, presence: true
  validates :role, inclusion: {
    in: %w[customer_service photographer editor receptionist assistant manager]
  }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :user_id, uniqueness: { scope: :tenant_id }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :with_login, -> { where(has_login: true) }
  scope :without_login, -> { where(has_login: false) }
  scope :by_role, ->(role) { where(role: role) }
  scope :photographers, -> { where(role: 'photographer') }
  scope :editors, -> { where(role: 'editor') }
  scope :customer_service, -> { where(role: 'customer_service') }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def can_login?
    has_login && user.present?
  end

  def display_role
    role.humanize
  end

  def photographer?
    role == 'photographer'
  end

  def editor?
    role == 'editor'
  end

  def customer_service?
    role == 'customer_service'
  end
end
