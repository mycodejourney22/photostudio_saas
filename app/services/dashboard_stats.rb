class DashboardStats
  attr_reader :tenant, :user

  def initialize(tenant, user)
    @tenant = tenant
    @user = user
  end

  def today_bookings
    @today_bookings ||= tenant.appointments.today.count
  end

  def week_revenue
    @week_revenue ||= tenant.appointments
                           .where(created_at: 1.week.ago..Time.current)
                           .completed
                           .sum(:price)
  end

  def active_customers
    @active_customers ||= tenant.customers.active.count
  end

  def customer_satisfaction
    # Mock data - in real app, calculate from reviews/ratings
    98.0
  end

  def upcoming_appointments
    @upcoming_appointments ||= tenant.appointments
                                    .upcoming
                                    .includes(:customer, :user, :studio)
                                    .limit(5)
  end

  def monthly_bookings_usage
    current_usage = tenant.appointments.current_month.count
    limit = tenant.plan_limits.limit_for('bookings')

    {
      current: current_usage,
      limit: limit,
      percentage: tenant.plan_limits.usage_percentage('bookings', current_usage)
    }
  end

  def storage_usage
    # Calculate actual storage usage
    current_usage = 0 # Implement storage calculation
    limit = tenant.plan_limits.limit_for('storage')

    {
      current: current_usage,
      limit: limit,
      percentage: tenant.plan_limits.usage_percentage('storage', current_usage)
    }
  end

  def team_members_usage
    current_usage = tenant.users.active.count
    limit = tenant.plan_limits.limit_for('team_members')

    {
      current: current_usage,
      limit: limit,
      percentage: tenant.plan_limits.usage_percentage('team_members', current_usage)
    }
  end

  def revenue_trend
    # Return last 6 months revenue data for charts
    (5.months.ago..Date.current).map do |month|
      {
        month: month.strftime('%b %Y'),
        revenue: tenant.appointments
                      .where(created_at: month.beginning_of_month..month.end_of_month)
                      .completed
                      .sum(:price)
      }
    end
  end

  def plan_limits
    tenant.plan_limits
  end
end
