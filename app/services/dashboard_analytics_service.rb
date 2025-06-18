# app/services/dashboard_analytics_service.rb
class DashboardAnalyticsService
  attr_reader :tenant, :date, :user, :ability

  def initialize(tenant, user, date = Date.current)
    @tenant = tenant
    @user = user
    @date = date
    @ability = Ability.new(user, tenant)
  end

  def daily_sales_metrics
    authorized_sales = authorized_sales_scope
    todays_sales = authorized_sales.where(sale_date: date.all_day).sum(:total_amount)
    yesterdays_sales = authorized_sales.where(sale_date: (date - 1.day).all_day).sum(:total_amount)

    {
      amount: todays_sales,
      yesterday_amount: yesterdays_sales,
      change: todays_sales - yesterdays_sales,
      percentage_change: calculate_percentage_change(yesterdays_sales, todays_sales)
    }
  end

  def active_photoshoots_metrics
    authorized_appointments = authorized_appointments_scope

    todays_photoshoots = authorized_appointments
                          .where(scheduled_at: date.all_day)
                          .where("assigned_photographer_id IS NOT NULL OR assigned_editor_id IS NOT NULL")
                          .count

    yesterdays_photoshoots = authorized_appointments
                              .where(scheduled_at: (date - 1.day).all_day)
                              .where("assigned_photographer_id IS NOT NULL OR assigned_editor_id IS NOT NULL")
                              .count

    {
      count: todays_photoshoots,
      yesterday_count: yesterdays_photoshoots,
      change: todays_photoshoots - yesterdays_photoshoots
    }
  end

  def booking_metrics
    authorized_appointments = authorized_appointments_scope
    todays_bookings = authorized_appointments.where(scheduled_at: date.all_day).count
    yesterdays_bookings = authorized_appointments.where(scheduled_at: (date - 1.day).all_day).count

    {
      count: todays_bookings,
      yesterday_count: yesterdays_bookings,
      change: todays_bookings - yesterdays_bookings
    }
  end

  def expense_metrics
    authorized_expenses = authorized_expenses_scope
    todays_expenses = authorized_expenses.where(expense_date: date).sum(:amount)
    yesterdays_expenses = authorized_expenses.where(expense_date: date - 1.day).sum(:amount)

    {
      amount: todays_expenses,
      yesterday_amount: yesterdays_expenses,
      change: todays_expenses - yesterdays_expenses,
      percentage_change: calculate_percentage_change(yesterdays_expenses, todays_expenses)
    }
  end

  def photographer_utilization
    authorized_staff = authorized_staff_scope
    photographers = authorized_staff.where(role: 'photographer', active: true)

    authorized_appointments = authorized_appointments_scope
    today_assignments = authorized_appointments
                         .where(scheduled_at: date.all_day)
                         .where.not(assigned_photographer_id: nil)
                         .group(:assigned_photographer_id)
                         .count

    photographers.map do |photographer|
      sessions_today = today_assignments[photographer.id] || 0
      max_sessions = 8 # Configurable max sessions per photographer per day

      {
        photographer: photographer,
        sessions_today: sessions_today,
        utilization_percentage: (sessions_today.to_f / max_sessions * 100).round(1),
        status: determine_photographer_status(sessions_today, max_sessions)
      }
    end
  end

  def revenue_by_service_type
    authorized_sales = authorized_sales_scope

    sales_with_service_data = authorized_sales
                               .where(sale_date: date)
                               .joins(sale_items: { service_tier: :service_package })
                               .group('service_packages.category')
                               .select(
                                 'service_packages.category',
                                 'COUNT(*) as booking_count',
                                 'SUM(sales.total_amount) as total_revenue'
                               )

    service_revenue = {}
    sales_with_service_data.each do |record|
      service_revenue[record.category] = {
        count: record.booking_count,
        revenue: record.total_revenue,
        avg_price: record.total_revenue / record.booking_count.to_f
      }
    end

    service_revenue
  end

  def operational_kpis
    authorized_appointments = authorized_appointments_scope

    # Booking capacity utilization (only for accessible studios)
    accessible_studios = user_accessible_studios
    total_daily_slots = accessible_studios.count * 8 # 8 slots per studio
    todays_bookings = authorized_appointments.where(scheduled_at: date.all_day).count
    capacity_utilization = total_daily_slots > 0 ?
                          (todays_bookings.to_f / total_daily_slots * 100).round(1) : 0

    # Average session length from completed appointments
    completed_today = authorized_appointments
                       .where(scheduled_at: date.all_day, status: 'completed')
    avg_session_length = completed_today.any? ?
                        (completed_today.average(:duration_minutes) / 60.0).round(1) : 0

    # Customer satisfaction (based on completion rate vs cancellation rate)
    total_recent = authorized_appointments.where(scheduled_at: 1.month.ago..date).count
    cancelled = authorized_appointments.where(scheduled_at: 1.month.ago..date, status: 'cancelled').count
    satisfaction = total_recent > 0 ?
                  (((total_recent - cancelled).to_f / total_recent) * 100).round(1) : 0

    # Overdue deliveries
    overdue_deliveries = authorized_appointments
                          .where(status: 'completed')
                          .where('scheduled_at < ?', 2.weeks.ago)
                          .where('delivery_date IS NULL OR delivery_date < ?', date)
                          .count

    {
      capacity_utilization: capacity_utilization,
      avg_session_hours: avg_session_length,
      satisfaction: satisfaction,
      overdue_deliveries: overdue_deliveries,
      studio_context: studio_context
    }
  end

  def financial_summary
    revenue = daily_sales_metrics[:amount]
    expenses = expense_metrics[:amount]

    {
      gross_revenue: revenue,
      total_expenses: expenses,
      net_profit: revenue - expenses,
      profit_margin: revenue > 0 ? ((revenue - expenses) / revenue * 100).round(1) : 0
    }
  end

  # Usage statistics for subscription limits
  def usage_statistics
    authorized_appointments = authorized_appointments_scope
    authorized_staff = authorized_staff_scope

    {
      monthly_bookings: {
        current: authorized_appointments.where(created_at: date.beginning_of_month..date.end_of_month).count,
        limit: tenant_booking_limit
      },
      team_members: {
        current: authorized_staff.where(active: true).count,
        limit: tenant_staff_limit
      },
      storage: {
        current: calculate_storage_usage,
        limit: tenant_storage_limit
      }
    }
  end

  # New method to get studio-specific analytics
  def studio_breakdown
    return {} unless user_can_view_multiple_studios?

    accessible_studios = user_accessible_studios

    accessible_studios.map do |studio|
      studio_sales = authorized_sales_scope.where(studio_location: studio).where(sale_date: date)
      studio_appointments = authorized_appointments_scope.where(studio_location: studio).where(scheduled_at: date.all_day)
      studio_expenses = authorized_expenses_scope.where(studio_location: studio).where(expense_date: date)

      {
        studio_name: studio.name,
        revenue: studio_sales.sum(:total_amount),
        bookings: studio_appointments.count,
        expenses: studio_expenses.sum(:amount),
        utilization: calculate_studio_utilization(studio, date)
      }
    end
  end

  private

  # Authorization scope methods
  def authorized_sales_scope
    @authorized_sales_scope ||= Sale.accessible_by(ability, :read).where(tenant: tenant)
  end

  def authorized_appointments_scope
    @authorized_appointments_scope ||= Appointment.accessible_by(ability, :read).where(tenant: tenant)
  end

  def authorized_expenses_scope
    @authorized_expenses_scope ||= Expense.accessible_by(ability, :read).where(tenant: tenant)
  end

  def authorized_staff_scope
    @authorized_staff_scope ||= StaffMember.accessible_by(ability, :read).where(tenant: tenant)
  end

  # User access helper methods
  def user_accessible_studios
    @user_accessible_studios ||= user.accessible_studio_locations(tenant)
  end

  def user_can_access_all_studios?
    user.can_access_all_studios?(tenant)
  end

  def user_can_view_multiple_studios?
    user_accessible_studios.count > 1
  end

  def studio_context
    {
      accessible_studios: user_accessible_studios.pluck(:name),
      is_filtered: !user_can_access_all_studios?,
      studio_count: user_accessible_studios.count
    }
  end

  # Tenant limits (get from subscription or settings)
  def tenant_booking_limit
    case tenant.plan_type
    when 'starter' then 100
    when 'professional' then 500
    when 'enterprise' then 999999
    else 100
    end
  end

  def tenant_staff_limit
    case tenant.plan_type
    when 'starter' then 2
    when 'professional' then 10
    when 'enterprise' then 999999
    else 2
    end
  end

  def tenant_storage_limit
    case tenant.plan_type
    when 'starter' then 10 * 1_073_741_824  # 10GB
    when 'professional' then 50 * 1_073_741_824  # 50GB
    when 'enterprise' then 500 * 1_073_741_824  # 500GB
    else 10 * 1_073_741_824
    end
  end

  # Utility methods
  def determine_photographer_status(sessions_today, max_sessions)
    utilization = sessions_today.to_f / max_sessions

    case utilization
    when 0
      'Available'
    when 0.1..0.7
      'Active'
    when 0.7..0.9
      'Busy'
    else
      'Fully Booked'
    end
  end

  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value.zero?
    ((new_value - old_value) / old_value.to_f * 100).round(1)
  end

  def calculate_studio_utilization(studio, date)
    studio_appointments = authorized_appointments_scope
                           .where(studio_location: studio)
                           .where(scheduled_at: date.all_day)
                           .count

    max_daily_slots = 8 # Configurable
    (studio_appointments.to_f / max_daily_slots * 100).round(1)
  end

  def calculate_storage_usage
    # Implement actual storage calculation based on your file storage system
    # This could involve checking Active Storage blob sizes, file system usage, etc.
    # For now, returning 0 as placeholder
    0
  end
end
