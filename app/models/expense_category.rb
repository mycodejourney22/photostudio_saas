class ExpenseCategory < ApplicationRecord
  acts_as_tenant :tenant

  has_many :expenses, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :tenant_id }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  # Default categories for new tenants
  DEFAULT_CATEGORIES = [
    { name: 'Production Equipment', description: 'Cameras, lenses, lighting, and studio equipment', color: '#3b82f6' },
    { name: 'Electricity & Utilities', description: 'Power, water, internet, and utility bills', color: '#eab308' },
    { name: 'Fuel & Transportation', description: 'Vehicle fuel, transportation costs, travel expenses', color: '#ef4444' },
    { name: 'General Supplies', description: 'Office supplies, cleaning materials, miscellaneous items', color: '#8b5cf6' },
    { name: 'Marketing & Advertising', description: 'Social media ads, print materials, promotional costs', color: '#06b6d4' },
    { name: 'Software & Subscriptions', description: 'Editing software, cloud storage, business tools', color: '#10b981' },
    { name: 'Rent & Facilities', description: 'Studio rent, facility maintenance, property costs', color: '#f59e0b' },
    { name: 'Insurance', description: 'Business insurance, equipment insurance, liability coverage', color: '#84cc16' },
    { name: 'Professional Services', description: 'Legal, accounting, consulting services', color: '#ec4899' },
    { name: 'Training & Education', description: 'Workshops, courses, professional development', color: '#6366f1' }
  ].freeze

  def can_be_deleted?
    expenses.none?
  end

  def total_expenses_this_month
    expenses.where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month)
            .sum(:amount)
  end

  def total_expenses_this_year
    expenses.where(expense_date: Date.current.beginning_of_year..Date.current.end_of_year)
            .sum(:amount)
  end
end
