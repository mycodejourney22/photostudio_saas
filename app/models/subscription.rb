class Subscription < ApplicationRecord
  belongs_to :subscriber, polymorphic: true

  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :plan_type, inclusion: { in: %w[starter professional enterprise] }
  validates :status, inclusion: { in: %w[active cancelled past_due unpaid paused] }

  scope :active, -> { where(status: 'active') }
  scope :expiring_soon, -> { where(current_period_end: ..7.days.from_now) }

  enum status: { active: 0, cancelled: 1, past_due: 2, unpaid: 3, paused: 4 }
  enum plan_type: { starter: 0, professional: 1, enterprise: 2 }

  def plan_limits
    @plan_limits ||= PlanLimits.new(plan_type)
  end

  def days_until_renewal
    (current_period_end.to_date - Date.current).to_i
  end

  def monthly_revenue
    case plan_type
    when 'starter' then 29
    when 'professional' then 79
    when 'enterprise' then 199
    end
  end
end
