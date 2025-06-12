class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable

  # Multi-tenancy
  has_many :tenant_users, dependent: :destroy
  has_many :tenants, through: :tenant_users
  has_many :appointments, dependent: :destroy

  # File attachments
  # has_one_attached :avatar

  # Validations
  validates :first_name, :last_name, presence: true, length: { maximum: 50 }
  validates :phone, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]{7,15}\z/ }, allow_blank: true

  # Callbacks
  before_validation :normalize_phone
  after_create :send_welcome_email

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { joins(:tenant_users).where(tenant_users: { role: role }) }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def primary_tenant
    tenant_users.joins(:tenant).where(tenants: { status: 'active' }).first&.tenant
  end

  def role_in_tenant(tenant)
    tenant_users.find_by(tenant: tenant)&.role
  end

  def can_access_tenant?(tenant)
    tenant_users.exists?(tenant: tenant)
  end

  private

  def normalize_phone
    self.phone = phone.to_s.gsub(/[^\d\+]/, '') if phone.present?
  end

  def send_welcome_email
    UserMailer.welcome_email(self).deliver_later
  end
end
