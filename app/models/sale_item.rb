# app/models/sale_item.rb
class SaleItem < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :sale
  belongs_to :service_tier, optional: true # For service-based items

  validates :item_type, inclusion: { in: %w[service product addon discount] }
  validates :name, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  enum item_type: { service: 0, product: 1, addon: 2, discount: 3 }

  before_save :calculate_total_price

  scope :services, -> { where(item_type: 'service') }
  scope :products, -> { where(item_type: 'product') }
  scope :addons, -> { where(item_type: 'addon') }
  scope :discounts, -> { where(item_type: 'discount') }

  def service?
    item_type == 'service'
  end

  def product?
    item_type == 'product'
  end

  def addon?
    item_type == 'addon'
  end

  def discount?
    item_type == 'discount'
  end

  def net_price
    total_price - (discount_amount || 0)
  end

  def display_name
    quantity > 1 ? "#{name} (#{quantity}x)" : name
  end

  # Common product categories for easy filtering
  def self.product_categories
    %w[
      passport prints frames albums digital
      canvas metal_prints photo_books
      accessories gift_cards
    ]
  end

  # Preset items for quick adding
  def self.passport_photos(quantity = 1, price = 25.0)
    {
      item_type: 'product',
      name: 'Passport Photos',
      description: '2x2 inch passport photos, set of 4',
      quantity: quantity,
      unit_price: price,
      product_category: 'passport'
    }
  end

  def self.extra_prints(size, quantity, price_per_print)
    {
      item_type: 'product',
      name: "#{size} Prints",
      description: "Professional quality prints",
      quantity: quantity,
      unit_price: price_per_print,
      product_category: 'prints',
      product_specifications: { size: size }
    }
  end

  def self.digital_gallery(price = 50.0)
    {
      item_type: 'product',
      name: 'Digital Gallery Access',
      description: 'Online gallery with download access',
      quantity: 1,
      unit_price: price,
      product_category: 'digital'
    }
  end

  def self.rush_service(price = 75.0)
    {
      item_type: 'addon',
      name: 'Rush Service',
      description: '24-hour delivery',
      quantity: 1,
      unit_price: price
    }
  end

  def self.discount_item(name, amount)
    {
      item_type: 'discount',
      name: name,
      quantity: 1,
      unit_price: -amount.abs, # Ensure it's negative
      total_price: -amount.abs
    }
  end

  private

  def calculate_total_price
    base_total = (unit_price || 0) * (quantity || 1)
    self.total_price = base_total - (discount_amount || 0)
  end
end
