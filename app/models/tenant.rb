# app/models/tenant.rb (updated with new relationships)
class Tenant < ApplicationRecord
  # extend FriendlyId
  # friendly_id :subdomain, use: :slugged

  has_many :tenant_users, dependent: :destroy
  has_many :users, through: :tenant_users
  has_many :customers, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :studios, dependent: :destroy
  has_many :subscriptions, as: :subscriber, dependent: :destroy
  has_many :staff_members, dependent: :destroy

  # New service package system
  has_many :service_packages, dependent: :destroy
  has_many :service_tiers, through: :service_packages
  has_many :studio_locations, dependent: :destroy

  has_one :branding, dependent: :destroy
  has_one_attached :logo

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subdomain, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :plan_type, inclusion: { in: %w[starter professional enterprise] }

  before_validation :normalize_subdomain
  before_create :generate_verification_token
  after_create :create_default_branding, :setup_default_services
  # after_create :setup_tenant_schema

  scope :active, -> { where(status: 'active') }
  scope :by_plan, ->(plan) { where(plan_type: plan) }

  # Updated enum to include 'pending' status
  enum status: { pending: 0, trial: 1, active: 2, suspended: 3, cancelled: 4 }
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

  # Check if tenant is verified
  def verified?
    verified_at.present?
  end

  # Verify the tenant
  def verify!
    update!(
      status: 'active',
      verified_at: Time.current,
      verification_token: nil  # Clear the token for security
    )
  end

  # Service package helpers
  def active_service_packages
    service_packages.active.ordered
  end

  def active_studio_locations
    studio_locations.active.ordered
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.downcase.strip
  end

  def generate_verification_token
    self.verification_token = SecureRandom.urlsafe_base64(32)
  end

  def create_default_branding
    build_branding(
      primary_color: '#667eea',
      secondary_color: '#764ba2',
      font_family: 'Inter',
      welcome_message: "Welcome to #{name}!"
    ).save!
  end

  def setup_default_services
    SetupDefaultServicesJob.perform_async(id)
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
      0
    when 'team_members'
      users.active.count
    end
  end
end
