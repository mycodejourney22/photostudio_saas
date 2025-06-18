# app/models/user.rb
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  # Associations
  has_many :tenant_users, dependent: :destroy
  has_many :tenants, through: :tenant_users
  has_one :staff_member, dependent: :nullify
  has_many :appointments, dependent: :restrict_with_error

  # Validations
  validates :first_name, :last_name, presence: true
  validates :first_name, :last_name, length: { minimum: 2, maximum: 50 }
  validates :phone, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]{7,15}\z/ }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :super_admins, -> { where(super_admin: true) }
  scope :regular_users, -> { where(super_admin: false) }
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def initials
    "#{first_name.first}#{last_name.first}".upcase
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive_account
  end

  # Super admin functionality
  def super_admin?
    super_admin == true
  end

  def make_super_admin!
    update!(super_admin: true)
  end

  def remove_super_admin!
    update!(super_admin: false)
  end

  # Role management within tenants
  def role_in_tenant(tenant)
    tenant_user = tenant_users.find_by(tenant: tenant)
    tenant_user&.role
  end

  def owner_of?(tenant)
    role_in_tenant(tenant) == 'owner'
  end

  def admin_of?(tenant)
    role_in_tenant(tenant)&.in?(['owner', 'admin'])
  end

  def staff_of?(tenant)
    role_in_tenant(tenant)&.in?(['owner', 'admin', 'staff'])
  end

  def can_manage_tenant?(tenant)
    super_admin? || admin_of?(tenant)
  end

  def can_access_setup?(tenant = nil)
    return true if super_admin? # System-level super admin can access any tenant
    return false unless tenant

    # Check if user is owner or admin of this specific tenant
    role_in_tenant(tenant)&.in?(['owner', 'admin'])
  end

  # Tenant access control (CRITICAL - this was missing!)
  def can_access_tenant?(tenant)
    return true if super_admin?
    return false unless tenant

    # Check if user belongs to this tenant
    tenant_users.exists?(tenant: tenant)
  end

  def primary_tenant
    # Return the first tenant where user is owner, or first tenant if no ownership
    owner_tenant = tenants.joins(:tenant_users)
                          .where(tenant_users: { role: 'owner' })
                          .first

    owner_tenant || tenants.first
  end

  # Staff member functionality
  def staff_member_in_tenant(tenant)
    ActsAsTenant.with_tenant(tenant) do
      tenant.staff_members.find_by(user: self)
    end
  end

  def has_staff_role?(role, tenant)
    staff_member = staff_member_in_tenant(tenant)
    staff_member&.role == role.to_s
  end

  # Authentication and security
  def password_expired?
    return false unless password_changed_at.present?
    password_changed_at < 90.days.ago
  end

  def force_password_change!
    update!(password_changed_at: 91.days.ago)
  end

  # Utility methods
  def display_email
    email.truncate(30)
  end

  def created_recently?
    created_at > 7.days.ago
  end

  def last_sign_in_display
    return 'Never' unless current_sign_in_at.present?

    if current_sign_in_at > 1.day.ago
      current_sign_in_at.strftime('%I:%M %p')
    elsif current_sign_in_at > 1.week.ago
      current_sign_in_at.strftime('%a %I:%M %p')
    else
      current_sign_in_at.strftime('%m/%d/%Y')
    end
  end

  # Preference management
  def preference(key, default = nil)
    preferences.fetch(key.to_s, default)
  end

  def set_preference(key, value)
    self.preferences = preferences.merge(key.to_s => value)
    save!
  end

  def current_staff_member(tenant)
    return nil unless staff_member&.tenant == tenant
    staff_member
  end

  def assigned_studio_location(tenant)
    current_staff_member(tenant)&.studio_location
  end

  def can_access_all_studios?(tenant)
    role = role_in_tenant(tenant)
    role&.in?(['owner', 'admin']) || super_admin?
  end

  # def accessible_studio_locations(tenant)
  #   return tenant.studio_locations if can_access_all_studios?(tenant)

  #   staff_member = current_staff_member(tenant)
  #   staff_member&.studio_location.present? ? [staff_member.studio_location] : []
  # end

  def accessible_studio_locations(tenant)
  return tenant.studio_locations if can_access_all_studios?(tenant)

  staff_member = current_staff_member(tenant)
  if staff_member&.studio_location.present?
    # FIXED: Return an ActiveRecord relation instead of Array
    tenant.studio_locations.where(id: staff_member.studio_location.id)
  else
    # Return empty relation instead of empty array
    tenant.studio_locations.none
  end
end

  def theme
    preference('theme', 'light')
  end

  def timezone
    preference('timezone', 'UTC')
  end

  def last_sign_in_display
    # Check if trackable columns exist
    if respond_to?(:current_sign_in_at) && current_sign_in_at.present?
      if current_sign_in_at > 1.day.ago
        current_sign_in_at.strftime('%I:%M %p')
      elsif current_sign_in_at > 1.week.ago
        current_sign_in_at.strftime('%a %I:%M %p')
      else
        current_sign_in_at.strftime('%m/%d/%Y')
      end
    elsif respond_to?(:last_sign_in_at) && last_sign_in_at.present?
      if last_sign_in_at > 1.day.ago
        last_sign_in_at.strftime('%I:%M %p')
      elsif last_sign_in_at > 1.week.ago
        last_sign_in_at.strftime('%a %I:%M %p')
      else
        last_sign_in_at.strftime('%m/%d/%Y')
      end
    else
      'Never'
    end
  end

  def most_recent_sign_in
    if respond_to?(:current_sign_in_at) && current_sign_in_at.present?
      current_sign_in_at
    elsif respond_to?(:last_sign_in_at) && last_sign_in_at.present?
      last_sign_in_at
    else
      nil
    end
  end

  # Additional method to check if user has signed in recently
  def has_signed_in?
    if respond_to?(:current_sign_in_at)
      current_sign_in_at.present?
    elsif respond_to?(:last_sign_in_at)
      last_sign_in_at.present?
    else
      false
    end
  end


  def notifications_enabled?
    preference('notifications_enabled', true)
  end

  # Class methods
  class << self
    def find_super_admin_by_email(email)
      super_admins.find_by(email: email)
    end

    def create_super_admin!(attributes)
      user = new(attributes)
      user.super_admin = true
      user.confirmed_at = Time.current # Auto-confirm super admins
      user.save!
      user
    end

    def setup_first_super_admin!
      return if super_admins.exists?

      create_super_admin!(
        email: 'admin@photostudio.com',
        password: SecureRandom.alphanumeric(12),
        first_name: 'Super',
        last_name: 'Admin'
      )
    end

    def active_count
      active.count
    end

    def recent_signups(days = 7)
      where('created_at > ?', days.days.ago)
    end
  end

  private

  def normalize_phone
    return unless phone.present?

    # Remove all non-numeric characters except + at the beginning
    self.phone = phone.gsub(/[^\d+]/, '')

    # Ensure + is only at the beginning
    if phone.include?('+') && !phone.starts_with?('+')
      self.phone = phone.gsub('+', '')
    end
  end

  # Callbacks
  before_validation :normalize_phone
  before_create :set_default_preferences
  after_create :send_welcome_notification

  def set_default_preferences
    self.preferences ||= {
      'theme' => 'light',
      'timezone' => 'UTC',
      'notifications_enabled' => true,
      'dashboard_layout' => 'default'
    }
  end

  def send_welcome_notification
    return if super_admin? # Don't send welcome emails to super admins

    # Send welcome email after user creation
    # UserMailer.welcome_email(self).deliver_later if persisted?
    Rails.logger.info "User #{email} registered - welcome email skipped (UserMailer not implemented)"

  end
end

# Create a simple command to make a user super admin
# Usage: rails runner "User.find_by(email: 'your@email.com')&.make_super_admin!"
