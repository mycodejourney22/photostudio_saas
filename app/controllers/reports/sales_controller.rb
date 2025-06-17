# app/controllers/reports/sales_controller.rb
class Reports::SalesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_date_range

  def daily
    @date = params[:date]&.to_date || Date.current
    @sales = current_tenant.sales.where(sale_date: @date.all_day)
                          .includes(:customer, :staff_member, :appointment, :sale_items)
                          .order(:sale_date)

    @daily_stats = calculate_daily_stats(@date)
    @sale_items = current_tenant.sale_items.joins(:sale)
                                .where(sales: { sale_date: @date.all_day })
                                .includes(:sale)
  end

  def monthly
    @date = Date.new(params[:year]&.to_i || Date.current.year,
                     params[:month]&.to_i || Date.current.month, 1)
    @month_range = @date.beginning_of_month..@date.end_of_month

    # Get daily sales data for the month
    @daily_sales = current_tenant.sales.where(sale_date: @month_range)
                                      .group("DATE(sale_date)")
                                      .sum(:total_amount)

    # Monthly stats
    @monthly_stats = calculate_monthly_stats(@date)

    # Weekly breakdown
    @weekly_stats = calculate_weekly_stats(@date)

    # Top performing days
    @top_days = current_tenant.sales.where(sale_date: @month_range)
                              .group("DATE(sale_date)")
                              .select("DATE(sale_date) as sale_day, SUM(total_amount) as daily_total")
                              .order("daily_total DESC")
                              .limit(10)
  end

  def weekly
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_week
    @end_date = @start_date.end_of_week
    @week_range = @start_date..@end_date

    @weekly_sales = current_tenant.sales.where(sale_date: @week_range)
                                        .includes(:customer, :staff_member, :appointment)
                                        .order(:sale_date)

    @weekly_stats = calculate_weekly_period_stats(@week_range)
  end

  def yearly
    @year = params[:year]&.to_i || Date.current.year
    @year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    # Monthly breakdown for the year
    @monthly_breakdown = current_tenant.sales.where(sale_date: @year_range)
                                           .group("EXTRACT(MONTH FROM sale_date)")
                                           .sum(:total_amount)

    @yearly_stats = calculate_yearly_stats(@year)
  end

  def by_staff
    @staff_member = current_tenant.staff_members.find(params[:staff_id]) if params[:staff_id].present?
    @date_range = parse_date_range

    if @staff_member
      @sales = @staff_member.sales.where(sale_date: @date_range)
                           .includes(:customer, :appointment, :sale_items)
                           .order(sale_date: :desc)
      @staff_stats = calculate_staff_stats(@staff_member, @date_range)
    else
      # Show all staff performance
      @staff_performance = current_tenant.staff_members.active.map do |staff|
        {
          staff: staff,
          sales_count: staff.sales.where(sale_date: @date_range).count,
          total_revenue: staff.sales.where(sale_date: @date_range).sum(:total_amount),
          avg_sale: staff.sales.where(sale_date: @date_range).average(:total_amount) || 0
        }
      end.sort_by { |s| s[:total_revenue] }.reverse
    end

    @staff_members = current_tenant.staff_members.active.order(:first_name, :last_name)
  end

  def by_service
    @date_range = parse_date_range

    # Service performance
    @service_stats = current_tenant.sale_items.joins(:sale)
                                              .where(sales: { sale_date: @date_range })
                                              .where(item_type: 'service')
                                              .group(:name)
                                              .select('name, COUNT(*) as count, SUM(total_price) as revenue')
                                              .order('revenue DESC')

    # Product performance
    @product_stats = current_tenant.sale_items.joins(:sale)
                                              .where(sales: { sale_date: @date_range })
                                              .where(item_type: 'product')
                                              .group(:name)
                                              .select('name, COUNT(*) as count, SUM(total_price) as revenue')
                                              .order('revenue DESC')
  end

  def payment_summary
    @date_range = parse_date_range

    @payment_stats = {
      paid: current_tenant.sales.where(sale_date: @date_range, payment_status: 'paid'),
      partial: current_tenant.sales.where(sale_date: @date_range, payment_status: 'partial'),
      unpaid: current_tenant.sales.where(sale_date: @date_range, payment_status: 'unpaid')
    }

    @payment_methods = current_tenant.sales.where(sale_date: @date_range)
                                          .where.not(payment_method: nil)
                                          .group(:payment_method)
                                          .sum(:paid_amount)
  end

  def outstanding
    @outstanding_sales = current_tenant.sales.where(payment_status: ['unpaid', 'partial'])
                                            .includes(:customer, :staff_member, :appointment)
                                            .order(:sale_date)

    @overdue_sales = @outstanding_sales.where('sale_date < ?', 30.days.ago)
    @recent_outstanding = @outstanding_sales.where('sale_date >= ?', 30.days.ago)

    @outstanding_stats = {
      total_outstanding: @outstanding_sales.sum('total_amount - COALESCE(paid_amount, 0)'),
      overdue_amount: @overdue_sales.sum('total_amount - COALESCE(paid_amount, 0)'),
      count: @outstanding_sales.count,
      overdue_count: @overdue_sales.count
    }
  end

  private

  def set_date_range
    @date_range = parse_date_range
  end

  def parse_date_range
    if params[:start_date].present? && params[:end_date].present?
      Date.parse(params[:start_date])..Date.parse(params[:end_date])
    else
      Date.current.beginning_of_month..Date.current.end_of_month
    end
  end

  def calculate_daily_stats(date)
    sales = current_tenant.sales.where(sale_date: date.all_day)

    {
      total_sales: sales.count,
      total_revenue: sales.sum(:total_amount),
      avg_sale: sales.average(:total_amount) || 0,
      paid_sales: sales.where(payment_status: 'paid').count,
      pending_payment: sales.where(payment_status: ['unpaid', 'partial']).count,
      total_paid: sales.sum(:paid_amount),
      outstanding: sales.sum('total_amount - COALESCE(paid_amount, 0)')
    }
  end

  def calculate_monthly_stats(date)
    month_range = date.beginning_of_month..date.end_of_month
    sales = current_tenant.sales.where(sale_date: month_range)

    {
      total_sales: sales.count,
      total_revenue: sales.sum(:total_amount),
      avg_sale: sales.average(:total_amount) || 0,
      avg_daily: sales.sum(:total_amount) / Date.current.day,
      paid_sales: sales.where(payment_status: 'paid').count,
      total_paid: sales.sum(:paid_amount),
      outstanding: sales.sum('total_amount - COALESCE(paid_amount, 0)'),
      best_day: sales.group("DATE(sale_date)").sum(:total_amount).max_by { |k, v| v }&.first,
      active_days: sales.group("DATE(sale_date)").count.keys.count
    }
  end

  def calculate_weekly_stats(date)
    month_range = date.beginning_of_month..date.end_of_month
    weeks = []

    current_week_start = date.beginning_of_month.beginning_of_week
    while current_week_start <= date.end_of_month
      week_end = [current_week_start.end_of_week, date.end_of_month].min
      week_range = current_week_start..week_end

      week_sales = current_tenant.sales.where(sale_date: week_range)
      weeks << {
        start_date: current_week_start,
        end_date: week_end,
        sales_count: week_sales.count,
        revenue: week_sales.sum(:total_amount)
      }

      current_week_start = current_week_start.next_week
    end

    weeks
  end

  def calculate_weekly_period_stats(week_range)
    sales = current_tenant.sales.where(sale_date: week_range)

    {
      total_sales: sales.count,
      total_revenue: sales.sum(:total_amount),
      avg_sale: sales.average(:total_amount) || 0,
      daily_breakdown: sales.group("DATE(sale_date)").sum(:total_amount),
      payment_status: {
        paid: sales.where(payment_status: 'paid').count,
        partial: sales.where(payment_status: 'partial').count,
        unpaid: sales.where(payment_status: 'unpaid').count
      }
    }
  end

  def calculate_yearly_stats(year)
    year_range = Date.new(year, 1, 1)..Date.new(year, 12, 31)
    sales = current_tenant.sales.where(sale_date: year_range)

    {
      total_sales: sales.count,
      total_revenue: sales.sum(:total_amount),
      avg_monthly: sales.sum(:total_amount) / 12,
      best_month: sales.group("EXTRACT(MONTH FROM sale_date)").sum(:total_amount).max_by { |k, v| v }&.first,
      growth_rate: calculate_growth_rate(year),
      quarterly_breakdown: calculate_quarterly_breakdown(year)
    }
  end

  def calculate_staff_stats(staff_member, date_range)
    sales = staff_member.sales.where(sale_date: date_range)

    {
      total_sales: sales.count,
      total_revenue: sales.sum(:total_amount),
      avg_sale: sales.average(:total_amount) || 0,
      conversion_rate: calculate_conversion_rate(staff_member, date_range),
      top_services: sales.joins(:sale_items)
                        .where(sale_items: { item_type: 'service' })
                        .group('sale_items.name')
                        .sum('sale_items.total_price')
                        .sort_by { |k, v| v }.reverse.first(5)
    }
  end

  def calculate_growth_rate(year)
    current_year_sales = current_tenant.sales.where(sale_date: Date.new(year, 1, 1)..Date.new(year, 12, 31)).sum(:total_amount)
    previous_year_sales = current_tenant.sales.where(sale_date: Date.new(year-1, 1, 1)..Date.new(year-1, 12, 31)).sum(:total_amount)

    return 0 if previous_year_sales.zero?
    ((current_year_sales - previous_year_sales) / previous_year_sales * 100).round(2)
  end

  def calculate_quarterly_breakdown(year)
    quarters = []
    (1..4).each do |quarter|
      start_month = (quarter - 1) * 3 + 1
      end_month = quarter * 3

      quarter_start = Date.new(year, start_month, 1)
      quarter_end = Date.new(year, end_month, -1)

      quarter_sales = current_tenant.sales.where(sale_date: quarter_start..quarter_end)
      quarters << {
        quarter: quarter,
        sales_count: quarter_sales.count,
        revenue: quarter_sales.sum(:total_amount)
      }
    end
    quarters
  end

  def calculate_conversion_rate(staff_member, date_range)
    # This would need appointments data to calculate properly
    # For now, return a placeholder
    appointments = current_tenant.appointments.where(staff_member: staff_member, scheduled_at: date_range)
    sales = staff_member.sales.where(sale_date: date_range)

    return 0 if appointments.count.zero?
    (sales.count.to_f / appointments.count * 100).round(2)
  end
end
