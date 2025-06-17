# app/services/dashboard_analytics_service.rb
class DashboardAnalyticsService
  attr_reader :tenant, :date

  def initialize(tenant, date = Date.current)
    @tenant = tenant
    @date = date
  end

  def daily_sales_metrics
    todays_sales = tenant.sales.where(sale_date: date).sum(:total_amount)
    yesterdays_sales = tenant.sales.where(sale_date: date - 1.day).sum(:total_amount)

    {
      amount: todays_sales,
      yesterday_amount: yesterdays_sales,
      change: todays_sales - yesterdays_sales,
      percentage_change: calculate_percentage_change(yesterdays_sales, todays_sales)
    }
  end

  def active_photoshoots_metrics
    todays_photoshoots = tenant.appointments
                              .where(scheduled_at: date.all_day)
                              .where("assigned_photographer_id IS NOT NULL OR assigned_editor_id IS NOT NULL")
                              .count

    yesterdays_photoshoots = tenant.appointments
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
    todays_bookings = tenant.appointments.where(scheduled_at: date.all_day).count
    yesterdays_bookings = tenant.appointments.where(scheduled_at: (date - 1.day).all_day).count

    {
      count: todays_bookings,
      yesterday_count: yesterdays_bookings,
      change: todays_bookings - yesterdays_bookings
    }
  end

  def expense_metrics
    todays_expenses = tenant.expenses.where(expense_date: date).sum(:amount)
    yesterdays_expenses = tenant.expenses.where(expense_date: date - 1.day).sum(:amount)

    {
      amount: todays_expenses,
      yesterday_amount: yesterdays_expenses,
      change: todays_expenses - yesterdays_expenses,
      percentage_change: calculate_percentage_change(yesterdays_expenses, todays_expenses)
    }
  end

  def photographer_utilization
    photographers = tenant.staff_members.where(role: 'photographer', active: true)
    today_assignments = tenant.appointments
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
    sales_with_service_data = tenant.sales
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
    # Booking capacity utilization
    total_daily_slots = 8 # Make this configurable
    todays_bookings = tenant.appointments.where(scheduled_at: date.all_day).count
    capacity_utilization = (todays_bookings.to_f / total_daily_slots * 100).round(1)

    # Average session length from completed appointments
    completed_today = tenant.appointments
                           .where(scheduled_at: date.all_day, status: 'completed')
    avg_session_length = completed_today.any? ?
                        (completed_today.average(:duration_minutes) / 60.0).round(1) : 0

    # Customer satisfaction (based on completion rate vs cancellation rate)
    total_recent = tenant.appointments.where(scheduled_at: 1.month.ago..date).count
    cancelled = tenant.appointments.where(scheduled_at: 1.month.ago..date, status: 'cancelled').count
    satisfaction = total_recent > 0 ?
                  (((total_recent - cancelled).to_f / total_recent) * 100).round(1) : 0

    # Overdue deliveries
    overdue_deliveries = tenant.appointments
                              .where(status: 'completed')
                              .where('scheduled_at < ?', 2.weeks.ago)
                              .where('delivery_date IS NULL OR delivery_date < ?', date)
                              .count

    {
      capacity_utilization: capacity_utilization,
      avg_session_hours: avg_session_length,
      satisfaction: satisfaction,
      overdue_deliveries: overdue_deliveries
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
    {
      monthly_bookings: {
        current: tenant.appointments.where(created_at: date.beginning_of_month..date.end_of_month).count,
        limit: 500 # Get from tenant subscription plan
      },
      team_members: {
        current: tenant.staff_members.where(active: true).count,
        limit: 10 # Get from tenant subscription plan
      },
      storage: {
        current: calculate_storage_usage,
        limit: 50 * 1_073_741_824 # 50GB in bytes
      }
    }
  end

  private

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

  def calculate_storage_usage
    # Implement actual storage calculation based on your file storage system
    # This could involve checking Active Storage blob sizes, file system usage, etc.
    # For now, returning 0 as placeholder
    0
  end
end
