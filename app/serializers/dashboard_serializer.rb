class DashboardSerializer < ApplicationSerializer
  attributes :today_bookings, :week_revenue, :active_customers,
             :customer_satisfaction, :monthly_bookings_usage,
             :storage_usage, :team_members_usage

  attribute :upcoming_appointments do |stats|
    stats.upcoming_appointments.map do |appointment|
      AppointmentSerializer.new(appointment).serializable_hash[:data][:attributes]
    end
  end

  attribute :revenue_trend do |stats|
    stats.revenue_trend
  end

  attribute :plan_limits do |stats|
    stats.plan_limits
  end
end
