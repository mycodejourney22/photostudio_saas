# app/helpers/dashboard_helper.rb
module DashboardHelper
  def schedule_border_class(appointment)
    has_photographer = appointment.assigned_photographer.present?
    has_editor = appointment.assigned_editor.present?
    is_photoshoot = has_photographer || has_editor

    if appointment.completed?
      'border-blue-500'
    elsif is_photoshoot
      'border-purple-500'
    elsif appointment.confirmed?
      'border-green-500'
    else
      'border-yellow-500'
    end
  end

  def schedule_bg_class(appointment)
    has_photographer = appointment.assigned_photographer.present?
    has_editor = appointment.assigned_editor.present?
    is_photoshoot = has_photographer || has_editor

    if appointment.completed?
      'bg-blue-50 hover:bg-blue-100'
    elsif is_photoshoot
      'bg-purple-50 hover:bg-purple-100'
    elsif appointment.confirmed?
      'bg-green-50 hover:bg-green-100'
    else
      'bg-yellow-50 hover:bg-yellow-100'
    end
  end

  def format_currency(amount)
    "$#{number_with_delimiter(amount.to_f.round(2))}"
  end

  def format_percentage_change(change)
    return "No change" if change.zero?

    symbol = change > 0 ? "↗" : "↘"
    color = change > 0 ? "text-green-600" : "text-red-600"

    content_tag :span, class: color do
      "#{symbol} #{change > 0 ? '+' : ''}#{change}%"
    end
  end

  def photographer_status_badge(appointment)
    if appointment.assigned_photographer.present?
      content_tag :span, "📷 #{appointment.assigned_photographer.first_name} #{appointment.assigned_photographer.last_name}",
                  class: "text-xs text-purple-600 font-medium"
    else
      content_tag :span, "⚠ Needs photographer",
                  class: "text-xs text-amber-600 font-medium"
    end
  end

  def editor_status_badge(appointment)
    if appointment.assigned_editor.present?
      content_tag :span, "✂️ #{appointment.assigned_editor.first_name} #{appointment.assigned_editor.last_name}",
                  class: "text-xs text-blue-600 font-medium"
    else
      content_tag :span, "⚠ Needs editor",
                  class: "text-xs text-amber-600 font-medium"
    end
  end

  def operational_kpi_color(kpi_name, value)
    case kpi_name
    when :capacity_utilization
      value >= 80 ? 'text-green-600' : value >= 60 ? 'text-yellow-600' : 'text-red-600'
    when :overdue_deliveries
      value > 0 ? 'text-red-600' : 'text-green-600'
    when :satisfaction
      value >= 90 ? 'text-green-600' : value >= 80 ? 'text-yellow-600' : 'text-red-600'
    else
      'text-gray-600'
    end
  end

  def dashboard_metric_trend(current, previous)
    return { direction: 'neutral', change: 0, color: 'text-gray-500' } if previous.zero?

    change = current - previous
    percentage = (change / previous.to_f * 100).round(1)

    {
      direction: change > 0 ? 'up' : change < 0 ? 'down' : 'neutral',
      change: change,
      percentage: percentage,
      color: change > 0 ? 'text-green-600' : change < 0 ? 'text-red-600' : 'text-gray-500'
    }
  end

  def schedule_status_icon(appointment)
    has_photographer = appointment.assigned_photographer.present?
    has_editor = appointment.assigned_editor.present?

    if appointment.completed?
      '✅'
    elsif has_photographer || has_editor
      '📷'
    elsif appointment.confirmed?
      '✅'
    elsif appointment.pending?
      '⏳'
    else
      '📅'
    end
  end

  def format_time_range(start_time, duration_minutes)
    end_time = start_time + duration_minutes.minutes
    "#{start_time.strftime('%I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
  end

  def dashboard_alert_level(metric_name, value)
    alerts = {
      overdue_deliveries: { high: 3, medium: 1 },
      capacity_utilization: { low: 50, medium: 80 },
      expenses_over_budget: { high: 1000, medium: 500 }
    }

    return 'success' unless alerts[metric_name]

    thresholds = alerts[metric_name]

    case metric_name
    when :overdue_deliveries, :expenses_over_budget
      value >= thresholds[:high] ? 'danger' : value >= thresholds[:medium] ? 'warning' : 'success'
    when :capacity_utilization
      value <= thresholds[:low] ? 'danger' : value <= thresholds[:medium] ? 'warning' : 'success'
    else
      'success'
    end
  end

  def revenue_comparison_text(current, previous)
    change = current - previous
    return "Same as yesterday" if change.zero?

    direction = change > 0 ? "more than" : "less than"
    amount = format_currency(change.abs)

    "#{amount} #{direction} yesterday"
  end

  def usage_percentage(current, limit)
    return 0 if limit.zero?
    [(current.to_f / limit * 100).round(1), 100].min
  end

  def usage_status_color(percentage)
    if percentage >= 90
      'text-red-600'
    elsif percentage >= 75
      'text-yellow-600'
    else
      'text-green-600'
    end
  end

  def progress_bar_color(percentage)
    if percentage >= 90
      'bg-red-600'
    elsif percentage >= 75
      'bg-yellow-600'
    else
      'bg-green-600'
    end
  end

  # Helper to get real customer full name
  def customer_full_name(customer)
    "#{customer.first_name} #{customer.last_name}".strip
  end

  # Helper to get real staff member full name
  def staff_full_name(staff_member)
    "#{staff_member.first_name} #{staff_member.last_name}".strip
  end

  # Helper to determine if appointment needs attention
  def appointment_needs_attention?(appointment)
    return true if appointment.assigned_photographer.blank? && appointment.assigned_editor.blank? && !appointment.completed?
    return true if appointment.scheduled_at < 1.hour.from_now && appointment.pending?
    false
  end

  # Get service package name for an appointment
  def appointment_service_name(appointment)
    appointment.service_tier&.name ||
    appointment.service_package&.name ||
    appointment.session_type&.humanize ||
    'Appointment'
  end
end
