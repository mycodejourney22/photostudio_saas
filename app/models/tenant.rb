class Tenant < ApplicationRecord
  # extend FriendlyId

  # friendly_id :subdomain, use: :slugged

  has_many :tenant_users, dependent: :destroy
  has_many :users, through: :tenant_users
  has_many :customers, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :studios, dependent: :destroy
  has_many :subscriptions, as: :subscriber, dependent: :destroy

  has_one :branding, dependent: :destroy
  has_one_attached :logo

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subdomain, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :plan_type, inclusion: { in: %w[starter professional enterprise] }

  before_validation :normalize_subdomain
  after_create :create_default_branding
  # after_create :setup_tenant_schema

  scope :active, -> { where(status: 'active') }
  scope :by_plan, ->(plan) { where(plan_type: plan) }

  enum status: { trial: 0, active: 1, suspended: 2, cancelled: 3 }
  enum plan_type: { starter: 0, professional: 1, enterprise: 2 }

  def full_domain
    "#{subdomain}.#{Rails.application.config.app_domain}"
  end

  def plan_limits
    @plan_limits ||= PlanLimits.new(plan_type)
  end

  def within_limits?(resource_type)
    plan_limits.within_limit?(resource_type, current_usage(resource_type))
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.downcase.strip
  end

  def create_default_branding
    build_branding(
      primary_color: '#667eea',
      secondary_color: '#764ba2',
      font_family: 'Inter',
      welcome_message: "Welcome to #{name}!"
    ).save!
  end

  # def setup_tenant_schema
  #   TenantSetupJob.perform_async(id)
  # end

  def current_usage(resource_type)
    case resource_type
    when 'bookings'
      appointments.current_month.count
    when 'storage'
      # Calculate storage usage
    when 'team_members'
      users.active.count
    end
  end
end
