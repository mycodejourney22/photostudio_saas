# # app/controllers/dashboard_controller.rb
# class DashboardController < ApplicationController
#   before_action :authenticate_user!

#   def index
#     @oversight_stats = calculate_oversight_stats
#     @todays_schedule = build_todays_schedule
#     @sales_breakdown = build_sales_breakdown
#     @expenses_breakdown = build_expenses_breakdown
#     @operational_kpis = calculate_operational_kpis
#   end

#   private

#   def calculate_oversight_stats
#     today = Date.current
#     yesterday = 1.day.ago.to_date

#     # Today's sales
#     todays_sales = current_tenant.sales.where(sale_date: today).sum(:total_amount)
#     yesterdays_sales = current_tenant.sales.where(sale_date: yesterday).sum(:total_amount)

#     # Active photoshoots (appointments with photographers assigned)
#     todays_photoshoots = current_tenant.appointments
#                                      .today
#                                      .where.not(assigned_photographer_id: nil)
#                                      .count
#     yesterdays_photoshoots = current_tenant.appointments
#                                          .where(scheduled_at: yesterday.all_day)
#                                          .where.not(assigned_photographer_id: nil)
#                                          .count

#     # Total bookings
#     todays_bookings = current_tenant.appointments.today.count
#     yesterdays_bookings = current_tenant.appointments.where(scheduled_at: yesterday.all_day).count

#     # Today's expenses
#     todays_expenses = current_tenant.expenses.where(expense_date: today).sum(:amount)
#     yesterdays_expenses = current_tenant.expenses.where(expense_date: yesterday).sum(:amount)

#     {
#       sales: {
#         today: todays_sales,
#         yesterday: yesterdays_sales,
#         change: todays_sales - yesterdays_sales,
#         percentage_change: calculate_percentage_change(yesterdays_sales, todays_sales)
#       },
#       photoshoots: {
#         today: todays_photoshoots,
#         yesterday: yesterdays_photoshoots,
#         change: todays_photoshoots - yesterdays_photoshoots
#       },
#       bookings: {
#         today: todays_bookings,
#         yesterday: yesterdays_bookings,
#         change: todays_bookings - yesterdays_bookings
#       },
#       expenses: {
#         today: todays_expenses,
#         yesterday: yesterdays_expenses,
#         change: todays_expenses - yesterdays_expenses,
#         percentage_change: calculate_percentage_change(yesterdays_expenses, todays_expenses)
#       }
#     }
#   end

#   def build_todays_schedule
#     appointments = current_tenant.appointments
#                                 .today
#                                 .includes(:customer, :assigned_photographer, :service_tier)
#                                 .order(:scheduled_at)

#     appointments.map do |appointment|
#       {
#         id: appointment.id,
#         time: appointment.scheduled_at.strftime("%I:%M %p"),
#         client_name: appointment.customer.full_name,
#         service: appointment.service_tier_name,
#         status: appointment.status,
#         price: appointment.price,
#         photographer: appointment.assigned_photographer&.full_name,
#         has_photographer: appointment.assigned_photographer.present?,
#         session_type: appointment.session_type,
#         css_class: determine_schedule_css_class(appointment)
#       }
#     end
#   end

#   def build_sales_breakdown
#     today = Date.current
#     sales = current_tenant.sales.where(sale_date: today).includes(:sale_items, :service_tier)

#     # Group by service type
#     breakdown = {}
#     total_sales = 0

#     sales.each do |sale|
#       sale.sale_items.each do |item|
#         service_name = item.service_tier&.name || item.item_description
#         service_category = item.service_tier&.service_package&.name || 'Other'

#         breakdown[service_category] ||= { amount: 0, count: 0, items: [] }
#         breakdown[service_category][:amount] += item.unit_price * item.quantity
#         breakdown[service_category][:count] += item.quantity
#         breakdown[service_category][:items] << {
#           name: service_name,
#           amount: item.unit_price * item.quantity
#         }
#         total_sales += item.unit_price * item.quantity
#       end
#     end

#     {
#       breakdown: breakdown,
#       total: total_sales,
#       transaction_count: sales.count
#     }
#   end

#   def build_expenses_breakdown
#     today = Date.current
#     expenses = current_tenant.expenses.where(expense_date: today).includes(:expense_category)

#     by_category = expenses.group(:expense_category_id)
#                          .joins(:expense_category)
#                          .group('expense_categories.name')
#                          .sum(:amount)

#     total_expenses = expenses.sum(:amount)

#     expense_details = expenses.map do |expense|
#       {
#         description: expense.description,
#         category: expense.expense_category.name,
#         amount: expense.amount,
#         staff_member: expense.staff_member&.full_name
#       }
#     end

#     {
#       by_category: by_category,
#       details: expense_details,
#       total: total_expenses,
#       count: expenses.count
#     }
#   end

#   def calculate_operational_kpis
#     today = Date.current

#     # Booking capacity (assuming 8 slots per day max)
#     max_daily_capacity = 8
#     todays_bookings = current_tenant.appointments.today.count
#     capacity_utilization = (todays_bookings.to_f / max_daily_capacity * 100).round(1)

#     # Average session length
#     completed_today = current_tenant.appointments.today.completed
#     avg_session_length = completed_today.average(:duration_minutes) || 0
#     avg_hours = (avg_session_length / 60.0).round(1)

#     # Client satisfaction (mock - you'd calculate from reviews/ratings)
#     satisfaction = 94.0

#     # Overdue deliveries
#     overdue_count = current_tenant.appointments
#                                  .where('delivery_date < ?', today)
#                                  .where.not(status: 'completed')
#                                  .count

#     {
#       capacity_utilization: capacity_utilization,
#       avg_session_hours: avg_hours,
#       satisfaction: satisfaction,
#       overdue_deliveries: overdue_count
#     }
#   end

#   def determine_schedule_css_class(appointment)
#     if appointment.assigned_photographer.present?
#       if appointment.completed?
#         'completed'
#       else
#         'photoshoot'  # Has photographer assigned
#       end
#     elsif appointment.confirmed?
#       'confirmed'
#     else
#       'pending'
#     end
#   end

#   def calculate_percentage_change(old_value, new_value)
#     return 0 if old_value.zero?
#     ((new_value - old_value) / old_value.to_f * 100).round(1)
#   end
# end
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @dashboard_analytics = DashboardAnalyticsService.new(current_tenant, Date.current)
  end

  private

  # Remove the hardcoded methods since we're now using real data directly in the view
  # The view will access current_tenant directly to get real-time data
end
