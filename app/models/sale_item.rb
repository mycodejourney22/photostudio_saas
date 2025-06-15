# app/models/sale_item.rb
class SaleItem < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :sale
  belongs_to :service_tier, optional: true

  validates :item_type, presence: true, inclusion: { in: %w[service product package discount] }
  validates :name, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_tenant_from_sale
  before_validation :calculate_total_price
  before_validation :set_defaults

  scope :services, -> { where(item_type: 'service') }
  scope :products, -> { where(item_type: 'product') }
  scope :packages, -> { where(item_type: 'package') }
  scope :discounts, -> { where(item_type: 'discount') }

  def service?
    item_type == 'service'
  end

  def product?
    item_type == 'product'
  end

  def package?
    item_type == 'package'
  end

  def discount?
    item_type == 'discount'
  end

  def display_name
    name.present? ? name : "Unnamed #{item_type.humanize}"
  end

  def line_total
    total_price || 0
  end

  def discounted_total
    line_total - (discount_amount || 0)
  end

  private

  def set_tenant_from_sale
    self.tenant_id = sale&.tenant_id if sale.present?
  end

  def calculate_total_price
    if quantity.present? && unit_price.present?
      self.total_price = (quantity * unit_price).round(2)
    end
  end

  def set_defaults
    self.quantity ||= 1
    self.unit_price ||= 0
    self.total_price ||= 0
    self.discount_amount ||= 0
  end
end
