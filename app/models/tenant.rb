# app/models/tenant.rb (updated with sales associations)
class Tenant < ApplicationRecord
  # extend FriendlyId
  # friendly_id :subdomain, use: :slugged

  # User and tenant relationships
  has_many :tenant_users, dependent: :destroy
  has_many :users, through: :tenant_users

  # Core business entities
  has_many :customers, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :sales, dependent: :destroy  # ← Missing association added!
  has_many :sale_items, through: :sales
  has_many :staff_members, dependent: :destroy

  # Studio and location management
  has_many :studios, dependent: :destroy
  has_many :studio_locations, dependent: :destroy

  # Service management
  has_many :service_packages, dependent: :destroy
  has_many :service_tiers, through: :service_packages

  # System relationships
  has_many :subscriptions, as: :subscriber, dependent: :destroy
  has_one :branding, dependent: :destroy
  has_one_attached :logo

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subdomain, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :plan_type, inclusion: { in: %w[starter professional enterprise] }

  # Callbacks
  before_validation :normalize_subdomain
  before_create :generate_verification_token
  after_create :create_default_branding, :setup_default_services

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_plan, ->(plan) { where(plan_type: plan) }

  # Enums
  enum status: { pending: 0, trial: 1, active: 2, suspended: 3, cancelled: 4 }
  enum plan_type: { starter: 0, professional: 1, enterprise: 2 }

  # Instance methods
  def full_domain
    "#{subdomain}.#{Rails.application.config.app_domain}"
  end

  def plan_limits
    @plan_limits ||= PlanLimits.new(plan_type)
  end

  def within_limits?(resource_type)
    plan_limits.within_limit?(resource_type, current_usage(resource_type))
  end

  def verified?
    verified_at.present?
  end

  def verify!
    update!(
      status: 'active',
      verified_at: Time.current,
      verification_token: nil
    )
  end

  # Service package helpers
  def active_service_packages
    service_packages.active.ordered
  end

  def active_studio_locations
    studio_locations.active.ordered
  end

  # Sales and revenue helpers
  def total_revenue(period = :all_time)
    case period
    when :today
      sales.where(sale_date: Date.current.all_day).sum(:total_amount)
    when :this_week
      sales.where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week).sum(:total_amount)
    when :this_month
      sales.where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month).sum(:total_amount)
    when :this_year
      sales.where(sale_date: Date.current.beginning_of_year..Date.current.end_of_year).sum(:total_amount)
    else
      sales.sum(:total_amount)
    end
  end

  def total_sales_count(period = :all_time)
    case period
    when :today
      sales.where(sale_date: Date.current.all_day).count
    when :this_week
      sales.where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week).count
    when :this_month
      sales.where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month).count
    when :this_year
      sales.where(sale_date: Date.current.beginning_of_year..Date.current.end_of_year).count
    else
      sales.count
    end
  end

  def average_sale_amount(period = :all_time)
    revenue = total_revenue(period)
    count = total_sales_count(period)
    return 0 if count.zero?

    revenue / count
  end

  def outstanding_payments
    sales.where(payment_status: ['unpaid', 'partial']).sum('total_amount - COALESCE(paid_amount, 0)')
  end

  def top_selling_services(limit = 5)
    sale_items.joins(:service_tier)
              .where(item_type: 'service')
              .group('service_tiers.name')
              .order('COUNT(*) DESC')
              .limit(limit)
              .count
  end

  def monthly_revenue_trend(months = 12)
    sales.where(sale_date: months.months.ago.beginning_of_month..Date.current.end_of_month)
         .group_by_month(:sale_date)
         .sum(:total_amount)
  end

  # Staff helpers
  def active_photographers
    staff_members.photographers.active
  end

  def active_editors
    staff_members.editors.active
  end

  def customer_service_staff
    staff_members.customer_service.active
  end

  # Usage tracking for plan limits
  def current_usage(resource_type)
    case resource_type
    when :customers
      customers.count
    when :appointments_per_month
      appointments.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
    when :sales_per_month
      sales.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
    when :staff_members
      staff_members.active.count
    when :studio_locations
      studio_locations.active.count
    when :service_packages
      service_packages.active.count
    else
      0
    end
  end

  # Dashboard stats
  def dashboard_stats
    {
      today: {
        appointments: appointments.where(scheduled_at: Date.current.all_day).count,
        sales: total_sales_count(:today),
        revenue: total_revenue(:today)
      },
      this_week: {
        appointments: appointments.where(scheduled_at: Date.current.beginning_of_week..Date.current.end_of_week).count,
        sales: total_sales_count(:this_week),
        revenue: total_revenue(:this_week)
      },
      this_month: {
        appointments: appointments.where(scheduled_at: Date.current.beginning_of_month..Date.current.end_of_month).count,
        sales: total_sales_count(:this_month),
        revenue: total_revenue(:this_month)
      },
      outstanding_payments: outstanding_payments,
      active_customers: customers.active.count,
      total_customers: customers.count
    }
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
    # Create default service packages
    portrait_package = service_packages.create!(
      name: "Portrait Photography",
      slug: "portrait-photography",
      description: "Professional portrait photography sessions",
      category: "portrait",
      active: true,
      sort_order: 1
    )

    # Create default service tiers for portrait package
    portrait_package.service_tiers.create!([
      {
        name: "Basic Portrait Session",
        description: "30-minute portrait session with 5 edited photos",
        price: 150.00,
        duration_minutes: 30,
        active: true,
        sort_order: 1
      },
      {
        name: "Standard Portrait Session",
        description: "60-minute portrait session with 15 edited photos",
        price: 250.00,
        duration_minutes: 60,
        active: true,
        sort_order: 2
      },
      {
        name: "Premium Portrait Session",
        description: "90-minute portrait session with 30 edited photos",
        price: 400.00,
        duration_minutes: 90,
        active: true,
        sort_order: 3
      }
    ])

    # Create family package
    family_package = service_packages.create!(
      name: "Family Photography",
      slug: "family-photography",
      description: "Family portrait sessions for all occasions",
      category: "family",
      active: true,
      sort_order: 2
    )

    family_package.service_tiers.create!([
      {
        name: "Family Mini Session",
        description: "30-minute family session with 10 edited photos",
        price: 200.00,
        duration_minutes: 30,
        active: true,
        sort_order: 1
      },
      {
        name: "Family Full Session",
        description: "60-minute family session with 25 edited photos",
        price: 350.00,
        duration_minutes: 60,
        active: true,
        sort_order: 2
      }
    ])
  end
end
