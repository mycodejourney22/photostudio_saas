class PlanLimits
  LIMITS = {
    'starter' => {
      'bookings' => 100,
      'storage' => 2_000_000_000, # 2GB in bytes
      'team_members' => 2,
      'locations' => 1
    },
    'professional' => {
      'bookings' => 500,
      'storage' => 50_000_000_000, # 50GB
      'team_members' => 10,
      'locations' => 3
    },
    'enterprise' => {
      'bookings' => Float::INFINITY,
      'storage' => Float::INFINITY,
      'team_members' => Float::INFINITY,
      'locations' => Float::INFINITY
    }
  }.freeze

  def initialize(plan_type)
    @plan_type = plan_type.to_s
  end

  def limit_for(resource_type)
    LIMITS.dig(@plan_type, resource_type.to_s) || 0
  end

  def within_limit?(resource_type, current_usage)
    limit = limit_for(resource_type)
    limit == Float::INFINITY || current_usage < limit
  end

  def usage_percentage(resource_type, current_usage)
    limit = limit_for(resource_type)
    return 0 if limit == Float::INFINITY

    ((current_usage.to_f / limit) * 100).round(2)
  end
end
