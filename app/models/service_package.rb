# app/models/service_package.rb
class ServicePackage < ApplicationRecord
  acts_as_tenant :tenant

  has_many :service_tiers, dependent: :destroy
  has_many :appointments, dependent: :restrict_with_error

  has_many :service_package_studio_locations, dependent: :destroy
  has_many :studio_locations, through: :service_package_studio_locations

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: { scope: :tenant_id }
  has_one_attached :photo

  # validates :category, inclusion: {
  #   in: %w[portrait wedding family newborn maternity commercial event other]
  # }

  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(:sort_order, :name) }

  CATEGORIES = %w[
    portrait
    family
    wedding
    commercial
    event
    headshot
    maternity
    newborn
  ].freeze

  validates :category, inclusion: { in: CATEGORIES }


  scope :recent, -> { order(created_at: :desc) }
  scope :ordered, -> { order(:sort_order, :name) }


  before_validation :generate_slug, if: -> { name.present? && slug.blank? }

  def to_param
    slug
  end

  def active_tiers
    service_tiers.active.ordered
  end

  def starting_price
    active_tiers.minimum(:price) || 0
  end

  def can_be_deleted?
    !has_bookings?
  end

  def has_bookings?
    service_tiers.joins(:appointments).exists? if respond_to?(:service_tiers)
  end

  def starting_price
    service_tiers.active.minimum(:price) || 0
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
