class ExpenseAnalyticsService
  def initialize(tenant, params = {})
    @tenant = tenant
    @params = params
    @date_range = determine_date_range
  end

  def call
    {
      summary: calculate_summary,
      monthly_trends: calculate_monthly_trends,
      category_breakdown: calculate_category_breakdown,
      location_breakdown: calculate_location_breakdown,
      payment_status_breakdown: calculate_payment_status_breakdown,
      top_vendors: calculate_top_vendors,
      recurring_expenses: calculate_recurring_expenses
    }
  end

  private

  attr_reader :tenant, :params, :date_range

  def determine_date_range
    case params[:period]
    when '3months'
      3.months.ago.beginning_of_month..Date.current.end_of_month
    when '1year'
      1.year.ago.beginning_of_month..Date.current.end_of_month
    else # 6months default
      6.months.ago.beginning_of_month..Date.current.end_of_month
    end
  end

  def base_expenses
    @base_expenses ||= tenant.expenses
                            .includes(:expense_category, :studio_location)
                            .where(expense_date: date_range)
  end

  def calculate_summary
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    previous_month = 1.month.ago.beginning_of_month..1.month.ago.end_of_month

    current_month_total = tenant.expenses.where(expense_date: current_month).sum(:amount)
    previous_month_total = tenant.expenses.where(expense_date: previous_month).sum(:amount)

    {
      total_expenses: base_expenses.sum(:amount),
      current_month_total: current_month_total,
      previous_month_total: previous_month_total,
      month_over_month_change: calculate_percentage_change(previous_month_total, current_month_total),
      total_count: base_expenses.count,
      pending_approval_count: tenant.expenses.where(approval_status: :pending_approval).count,
      overdue_count: tenant.expenses.where(payment_status: :pending, expense_date: ..30.days.ago).count,
      average_expense: base_expenses.average(:amount)&.round(2) || 0
    }
  end

  def calculate_monthly_trends
    months = []
    start_date = date_range.begin

    while start_date <= date_range.end
      month_end = start_date.end_of_month
      month_expenses = base_expenses.where(expense_date: start_date..month_end)

      months << {
        month: start_date.strftime('%b %Y'),
        date: start_date,
        total: month_expenses.sum(:amount),
        count: month_expenses.count,
        categories: month_expenses.joins(:expense_category)
                                  .group('expense_categories.name')
                                  .sum(:amount)
      }

      start_date = start_date.next_month.beginning_of_month
    end

    months
  end

  def calculate_category_breakdown
    base_expenses.joins(:expense_category)
                 .group('expense_categories.name', 'expense_categories.color')
                 .sum(:amount)
                 .map do |(name, color), total|
      count = base_expenses.joins(:expense_category)
                           .where(expense_categories: { name: name })
                           .count

      {
        name: name,
        color: color,
        total: total,
        count: count,
        percentage: (total.to_f / base_expenses.sum(:amount) * 100).round(1)
      }
    end.sort_by { |cat| -cat[:total] }
  end

  def calculate_location_breakdown
    base_expenses.joins(:studio_location)
                 .group('studio_locations.name')
                 .sum(:amount)
                 .map do |location_name, total|
      count = base_expenses.joins(:studio_location)
                           .where(studio_locations: { name: location_name })
                           .count

      {
        name: location_name,
        total: total,
        count: count,
        percentage: (total.to_f / base_expenses.sum(:amount) * 100).round(1)
      }
    end.sort_by { |loc| -loc[:total] }
  end

  def calculate_payment_status_breakdown
    Expense.payment_statuses.keys.map do |status|
      count = base_expenses.where(payment_status: status).count
      total = base_expenses.where(payment_status: status).sum(:amount)

      {
        status: status.humanize,
        count: count,
        total: total,
        percentage: base_expenses.count > 0 ? (count.to_f / base_expenses.count * 100).round(1) : 0
      }
    end.reject { |status| status[:count] == 0 }
  end

  def calculate_top_vendors
    base_expenses.where.not(vendor_name: [nil, ''])
                 .group(:vendor_name)
                 .sum(:amount)
                 .sort_by { |vendor, total| -total }
                 .first(10)
                 .map do |vendor_name, total|
      count = base_expenses.where(vendor_name: vendor_name).count

      {
        name: vendor_name,
        total: total,
        count: count
      }
    end
  end

  def calculate_recurring_expenses
    recurring = tenant.expenses.where(recurring: true)
                      .includes(:expense_category, :studio_location)

    {
      total_recurring: recurring.count,
      monthly_recurring_cost: recurring.where(recurring_frequency: 'monthly').sum(:amount),
      due_this_month: recurring.where(next_due_date: Date.current.beginning_of_month..Date.current.end_of_month).count,
      upcoming_renewals: recurring.where(next_due_date: Date.current..1.month.from_now)
                                  .order(:next_due_date)
                                  .limit(10)
                                  .map do |expense|
        {
          title: expense.title,
          amount: expense.amount,
          next_due_date: expense.next_due_date,
          frequency: expense.recurring_frequency,
          category: expense.expense_category.name
        }
      end
    }
  end

  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value.nil? || old_value.zero?
    ((new_value - old_value).to_f / old_value * 100).round(1)
  end
end
