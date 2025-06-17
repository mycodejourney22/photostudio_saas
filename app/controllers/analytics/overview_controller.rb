# app/controllers/analytics/overview_controller.rb
class Analytics::OverviewController < ApplicationController
  before_action :authenticate_user!

  def index
    @date_range = parse_date_range
    @analytics_data = build_analytics_data

    respond_to do |format|
      format.html
      format.json { render json: @analytics_data }
    end
  end

  def revenue
    @date_range = parse_date_range
    @revenue_data = build_revenue_analytics

    respond_to do |format|
      format.html
      format.json { render json: @revenue_data }
    end
  end

  def bookings
    @date_range = parse_date_range
    @booking_analytics = build_booking_analytics

    respond_to do |format|
      format.html
      format.json { render json: @booking_analytics }
    end
  end

  def customers
    @date_range = parse_date_range
    @customer_analytics = build_customer_analytics

    respond_to do |format|
      format.html
      format.json { render json: @customer_analytics }
    end
  end

  def staff_performance
    @date_range = parse_date_range
    @staff_analytics = build_staff_analytics

    respond_to do |format|
      format.html
      format.json { render json: @staff_analytics }
    end
  end

  def service_popularity
    @date_range = parse_date_range
    @service_analytics = build_service_analytics

    respond_to do |format|
      format.html
      format.json { render json: @service_analytics }
    end
  end

  private

  def parse_date_range
    if params[:start_date].present? && params[:end_date].present?
      Date.parse(params[:start_date])..Date.parse(params[:end_date])
    elsif params[:period].present?
      case params[:period]
      when 'today'
        Date.current.all_day
      when 'week'
        Date.current.beginning_of_week..Date.current.end_of_week
      when 'month'
        Date.current.beginning_of_month..Date.current.end_of_month
      when 'quarter'
        Date.current.beginning_of_quarter..Date.current.end_of_quarter
      when 'year'
        Date.current.beginning_of_year..Date.current.end_of_year
      else
        Date.current.beginning_of_month..Date.current.end_of_month
      end
    else
      Date.current.beginning_of_month..Date.current.end_of_month
    end
  end

  def build_analytics_data
    {
      overview_stats: calculate_overview_stats,
      revenue_trend: calculate_revenue_trend,
      sales_distribution: calculate_sales_distribution,
      top_performers: calculate_top_performers,
      growth_metrics: calculate_growth_metrics,
      key_insights: generate_key_insights
    }
  end

  def build_revenue_analytics
    {
      total_revenue: calculate_total_revenue,
      revenue_by_period: calculate_revenue_by_period,
      revenue_by_service: calculate_revenue_by_service,
      revenue_by_staff: calculate_revenue_by_staff,
      payment_status_breakdown: calculate_payment_status_breakdown,
      revenue_forecast: calculate_revenue_forecast
    }
  end

  def build_booking_analytics
    {
      total_bookings: calculate_total_bookings,
      booking_trends: calculate_booking_trends,
      booking_sources: calculate_booking_sources,
      conversion_rates: calculate_conversion_rates,
      cancellation_rates: calculate_cancellation_rates,
      popular_time_slots: calculate_popular_time_slots
    }
  end

  def build_customer_analytics
    {
      total_customers: calculate_total_customers,
      new_customers: calculate_new_customers,
      repeat_customers: calculate_repeat_customers,
      customer_lifetime_value: calculate_customer_lifetime_value,
      customer_acquisition_cost: calculate_customer_acquisition_cost,
      customer_retention_rate: calculate_customer_retention_rate
    }
  end

  def build_staff_analytics
    current_tenant.staff_members.active.map do |staff|
      {
        staff: {
          id: staff.id,
          name: staff.full_name,
          role: staff.role
        },
        sales_metrics: calculate_staff_sales_metrics(staff),
        appointment_metrics: calculate_staff_appointment_metrics(staff),
        performance_score: calculate_staff_performance_score(staff)
      }
    end
  end

  def build_service_analytics
    {
      service_popularity: calculate_service_popularity,
      service_revenue: calculate_service_revenue,
      service_trends: calculate_service_trends,
      package_performance: calculate_package_performance
    }
  end

  def calculate_overview_stats
    sales = current_tenant.sales.where(sale_date: @date_range)

    {
      total_revenue: sales.sum(:total_amount),
      total_sales: sales.count,
      avg_sale_value: sales.average(:total_amount) || 0,
      total_customers: sales.joins(:customer).distinct.count('customers.id'),
      revenue_growth: calculate_period_growth(:revenue),
      sales_growth: calculate_period_growth(:sales_count)
    }
  end

  def calculate_revenue_trend
    sales_by_day = current_tenant.sales.where(sale_date: @date_range)
                                      .group("DATE(sale_date)")
                                      .sum(:total_amount)

    # Fill in missing dates with 0
    (@date_range.begin.to_date..@date_range.end.to_date).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        revenue: sales_by_day[date] || 0
      }
    end
  end

  def calculate_sales_distribution
    current_tenant.sales.where(sale_date: @date_range)
                       .group("DATE(sale_date)")
                       .count
  end

  def calculate_top_performers
    {
      top_staff: current_tenant.staff_members.joins(:sales)
                               .where(sales: { sale_date: @date_range })
                               .group('staff_members.id, staff_members.first_name, staff_members.last_name')
                               .sum('sales.total_amount')
                               .sort_by { |k, v| v }.reverse.first(5),

      top_services: current_tenant.sale_items.joins(:sale)
                                             .where(sales: { sale_date: @date_range })
                                             .where(item_type: 'service')
                                             .group(:name)
                                             .sum(:total_price)
                                             .sort_by { |k, v| v }.reverse.first(5),

      top_customers: current_tenant.sales.where(sale_date: @date_range)
                                         .group(:customer_id, :customer_name)
                                         .sum(:total_amount)
                                         .sort_by { |k, v| v }.reverse.first(5)
                                         .map { |(customer_id, customer_name), revenue| [[customer_id, customer_name], revenue] }
    }
  end

  def calculate_growth_metrics
    current_period_sales = current_tenant.sales.where(sale_date: @date_range)
    previous_period_sales = get_previous_period_sales

    {
      revenue_growth: calculate_growth_percentage(
        current_period_sales.sum(:total_amount),
        previous_period_sales.sum(:total_amount)
      ),
      sales_count_growth: calculate_growth_percentage(
        current_period_sales.count,
        previous_period_sales.count
      ),
      avg_sale_growth: calculate_growth_percentage(
        current_period_sales.average(:total_amount) || 0,
        previous_period_sales.average(:total_amount) || 0
      )
    }
  end

  def generate_key_insights
    insights = []

    # Revenue insights
    current_revenue = current_tenant.sales.where(sale_date: @date_range).sum(:total_amount)
    previous_revenue = get_previous_period_sales.sum(:total_amount)

    if current_revenue > previous_revenue && previous_revenue > 0
      growth = ((current_revenue - previous_revenue) / previous_revenue * 100).round(1)
      insights << {
        type: 'positive',
        title: 'Revenue Growth',
        message: "Revenue increased by #{growth}% compared to previous period"
      }
    elsif current_revenue == 0
      insights << {
        type: 'info',
        title: 'Getting Started',
        message: "No sales recorded yet for this period. Create your first sale to see analytics!"
      }
    end

    # Best performing day (only if there are sales)
    if current_revenue > 0
      best_day = current_tenant.sales.where(sale_date: @date_range)
                                    .group("DATE(sale_date)")
                                    .sum(:total_amount)
                                    .max_by { |k, v| v }

      if best_day
        date = best_day[0].is_a?(String) ? Date.parse(best_day[0]) : best_day[0]
        insights << {
          type: 'info',
          title: 'Peak Performance',
          message: "#{date.strftime('%A, %B %d')} was your highest revenue day"
        }
      end

      # Payment status insight
      unpaid_amount = current_tenant.sales.where(sale_date: @date_range, payment_status: ['unpaid', 'partial'])
                                         .sum('total_amount - COALESCE(paid_amount, 0)')

      if unpaid_amount > 0
        insights << {
          type: 'warning',
          title: 'Outstanding Payments',
          message: "₦#{number_with_delimiter(unpaid_amount)} in outstanding payments"
        }
      end
    end

    insights
  end

  def calculate_period_growth(metric)
    current_period = current_tenant.sales.where(sale_date: @date_range)
    previous_period = get_previous_period_sales

    case metric
    when :revenue
      current_value = current_period.sum(:total_amount)
      previous_value = previous_period.sum(:total_amount)
    when :sales_count
      current_value = current_period.count
      previous_value = previous_period.count
    end

    calculate_growth_percentage(current_value, previous_value)
  end

  def get_previous_period_sales
    period_length = @date_range.end - @date_range.begin
    previous_start = @date_range.begin - period_length - 1.day
    previous_end = @date_range.begin - 1.day

    current_tenant.sales.where(sale_date: previous_start..previous_end)
  end

  def calculate_growth_percentage(current, previous)
    return 0 if previous.zero? || previous.nil?
    ((current - previous) / previous.to_f * 100).round(2)
  end

  def calculate_total_revenue
    current_tenant.sales.where(sale_date: @date_range).sum(:total_amount)
  end

  def calculate_revenue_by_period
    if @date_range.end - @date_range.begin > 31.days
      # Group by month
      current_tenant.sales.where(sale_date: @date_range)
                         .group("EXTRACT(YEAR FROM sale_date), EXTRACT(MONTH FROM sale_date)")
                         .sum(:total_amount)
    else
      # Group by day
      current_tenant.sales.where(sale_date: @date_range)
                         .group("DATE(sale_date)")
                         .sum(:total_amount)
    end
  end

  def calculate_staff_sales_metrics(staff)
    staff_sales = staff.sales.where(sale_date: @date_range)

    {
      total_sales: staff_sales.count,
      total_revenue: staff_sales.sum(:total_amount),
      avg_sale_value: staff_sales.average(:total_amount) || 0,
      conversion_rate: calculate_staff_conversion_rate(staff)
    }
  end

  def calculate_staff_appointment_metrics(staff)
    staff_appointments = staff.appointments_as_photographer.where(scheduled_at: @date_range)

    {
      total_appointments: staff_appointments.count,
      completed_appointments: staff_appointments.where(status: 'completed').count,
      cancelled_appointments: staff_appointments.where(status: 'cancelled').count,
      no_shows: staff_appointments.where(status: 'no_show').count
    }
  end

  def calculate_staff_performance_score(staff)
    # Simple performance score based on revenue and customer satisfaction
    # This could be made more sophisticated based on your business needs

    sales_score = (staff.sales.where(sale_date: @date_range).sum(:total_amount) / 1000).clamp(0, 100)
    # Add other metrics as needed

    sales_score.round(1)
  end

  def calculate_staff_conversion_rate(staff)
    appointments = staff.appointments_as_photographer.where(scheduled_at: @date_range).count
    sales = staff.sales.where(sale_date: @date_range).count

    return 0 if appointments.zero?
    (sales.to_f / appointments * 100).round(2)
  end

  def calculate_revenue_by_service
    current_tenant.sale_items.joins(:sale)
                             .where(sales: { sale_date: @date_range })
                             .where(item_type: 'service')
                             .group(:name)
                             .sum(:total_price)
  end

  def calculate_revenue_by_staff
    current_tenant.staff_members.joins(:sales)
                                .where(sales: { sale_date: @date_range })
                                .group('staff_members.id, staff_members.first_name, staff_members.last_name')
                                .sum('sales.total_amount')
  end

  def calculate_payment_status_breakdown
    {
      paid: current_tenant.sales.where(sale_date: @date_range, payment_status: 'paid').sum(:total_amount),
      partial: current_tenant.sales.where(sale_date: @date_range, payment_status: 'partial').sum(:total_amount),
      unpaid: current_tenant.sales.where(sale_date: @date_range, payment_status: 'unpaid').sum(:total_amount)
    }
  end

  def calculate_revenue_forecast
    # Simple forecast based on current period trend
    current_total = current_tenant.sales.where(sale_date: @date_range).sum(:total_amount)
    days_in_period = (@date_range.end.to_date - @date_range.begin.to_date).to_i + 1
    days_passed = (Date.current - @date_range.begin.to_date).to_i + 1

    return 0 if days_passed <= 0

    daily_average = current_total / days_passed
    forecasted_total = daily_average * days_in_period

    {
      current_total: current_total,
      daily_average: daily_average,
      forecasted_total: forecasted_total,
      days_remaining: [days_in_period - days_passed, 0].max
    }
  end

  def calculate_total_bookings
    current_tenant.appointments.where(scheduled_at: @date_range).count
  end

  def calculate_booking_trends
    current_tenant.appointments.where(scheduled_at: @date_range)
                               .group("DATE(scheduled_at)")
                               .count
  end

  def calculate_booking_sources
    current_tenant.appointments.where(scheduled_at: @date_range)
                               .group(:booking_source)
                               .count
  end

  def calculate_conversion_rates
    total_appointments = current_tenant.appointments.where(scheduled_at: @date_range).count
    completed_appointments = current_tenant.appointments.where(scheduled_at: @date_range, status: 'completed').count
    sales_count = current_tenant.sales.where(sale_date: @date_range).count

    {
      completion_rate: total_appointments > 0 ? (completed_appointments.to_f / total_appointments * 100).round(2) : 0,
      sales_conversion_rate: completed_appointments > 0 ? (sales_count.to_f / completed_appointments * 100).round(2) : 0
    }
  end

  def calculate_cancellation_rates
    total_appointments = current_tenant.appointments.where(scheduled_at: @date_range).count
    cancelled_appointments = current_tenant.appointments.where(scheduled_at: @date_range, status: 'cancelled').count

    total_appointments > 0 ? (cancelled_appointments.to_f / total_appointments * 100).round(2) : 0
  end

  def calculate_popular_time_slots
    current_tenant.appointments.where(scheduled_at: @date_range)
                               .group("EXTRACT(HOUR FROM scheduled_at)")
                               .count
                               .sort_by { |hour, count| count }.reverse.first(5)
  end

  def calculate_total_customers
    current_tenant.customers.count
  end

  def calculate_new_customers
    current_tenant.customers.where(created_at: @date_range).count
  end

  def calculate_repeat_customers
    customer_ids_with_multiple_sales = current_tenant.sales.where(sale_date: @date_range)
                                                          .group(:customer_id)
                                                          .having('COUNT(*) > 1')
                                                          .count
                                                          .keys
    customer_ids_with_multiple_sales.count
  end

  def calculate_customer_lifetime_value
    total_customers = current_tenant.customers.count
    total_revenue = current_tenant.sales.sum(:total_amount)

    total_customers > 0 ? (total_revenue / total_customers).round(2) : 0
  end

  def calculate_customer_acquisition_cost
    # This would typically involve marketing spend data
    # For now, return a placeholder
    0
  end

  def calculate_customer_retention_rate
    # Calculate customers who made purchases in both current and previous period
    previous_period_customers = get_previous_period_sales.distinct.pluck(:customer_id)
    current_period_customers = current_tenant.sales.where(sale_date: @date_range).distinct.pluck(:customer_id)

    return 0 if previous_period_customers.empty?

    retained_customers = (previous_period_customers & current_period_customers).count
    (retained_customers.to_f / previous_period_customers.count * 100).round(2)
  end

  def calculate_service_popularity
    current_tenant.sale_items.joins(:sale)
                             .where(sales: { sale_date: @date_range })
                             .where(item_type: 'service')
                             .group(:name)
                             .count
                             .sort_by { |k, v| v }.reverse
  end

  def calculate_service_revenue
    current_tenant.sale_items.joins(:sale)
                             .where(sales: { sale_date: @date_range })
                             .where(item_type: 'service')
                             .group(:name)
                             .sum(:total_price)
                             .sort_by { |k, v| v }.reverse
  end

  def calculate_service_trends
    # Compare current period to previous period
    current_services = calculate_service_popularity

    # Get previous period data
    previous_period_length = @date_range.end - @date_range.begin
    previous_start = @date_range.begin - previous_period_length - 1.day
    previous_end = @date_range.begin - 1.day

    previous_services = current_tenant.sale_items.joins(:sale)
                                                 .where(sales: { sale_date: previous_start..previous_end })
                                                 .where(item_type: 'service')
                                                 .group(:name)
                                                 .count

    trends = {}
    current_services.each do |service, current_count|
      previous_count = previous_services[service] || 0
      if previous_count > 0
        growth = ((current_count - previous_count).to_f / previous_count * 100).round(2)
        trends[service] = { current: current_count, previous: previous_count, growth: growth }
      else
        trends[service] = { current: current_count, previous: 0, growth: 'new' }
      end
    end

    trends
  end

  def calculate_package_performance
    current_tenant.sale_items.joins(:sale)
                             .where(sales: { sale_date: @date_range })
                             .where(item_type: 'package')
                             .group(:name)
                             .select('name, COUNT(*) as count, SUM(total_price) as revenue')
                             .order('revenue DESC')
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
