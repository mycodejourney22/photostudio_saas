# app/helpers/appointments_helper.rb
module AppointmentsHelper
  def appointment_status_color(status)
    case status.to_s.downcase
    when 'confirmed'
      'bg-green-500'
    when 'pending'
      'bg-yellow-500'
    when 'cancelled'
      'bg-red-500'
    when 'completed'
      'bg-purple-500'
    when 'no_show'
      'bg-gray-500'
    else
      'bg-blue-500'
    end
  end

  def appointment_status_badge_classes(status)
    case status.to_s.downcase
    when 'confirmed'
      'bg-green-100 text-green-800'
    when 'pending'
      'bg-yellow-100 text-yellow-800'
    when 'cancelled'
      'bg-red-100 text-red-800'
    when 'completed'
      'bg-purple-100 text-purple-800'
    when 'no_show'
      'bg-gray-100 text-gray-800'
    else
      'bg-blue-100 text-blue-800'
    end
  end

  def format_appointment_time(appointment)
    appointment.scheduled_at.strftime("%I:%M %p")
  end

  def format_appointment_date(appointment)
    appointment.scheduled_at.strftime("%B %d, %Y")
  end

  def format_appointment_datetime(appointment)
    "#{format_appointment_date(appointment)} at #{format_appointment_time(appointment)}"
  end

  def appointment_duration_text(appointment)
    if appointment.duration_minutes.present?
      hours = appointment.duration_minutes / 60
      minutes = appointment.duration_minutes % 60

      if hours > 0 && minutes > 0
        "#{hours}h #{minutes}m"
      elsif hours > 0
        "#{hours}h"
      else
        "#{minutes}m"
      end
    else
      "Duration not set"
    end
  end

  def time_until_appointment(appointment)
    return "Past appointment" if appointment.scheduled_at < Time.current

    distance_of_time_in_words(Time.current, appointment.scheduled_at)
  end

  def appointment_urgency_class(appointment)
    return 'text-gray-500' if appointment.scheduled_at < Time.current

    time_diff = appointment.scheduled_at - Time.current

    if time_diff < 1.hour
      'text-red-600 font-semibold' # Very urgent - within 1 hour
    elsif time_diff < 4.hours
      'text-orange-600 font-medium' # Urgent - within 4 hours
    elsif time_diff < 24.hours
      'text-yellow-600' # Soon - within 24 hours
    else
      'text-gray-600' # Normal
    end
  end

  def can_send_reminder?(appointment)
    appointment.scheduled_at > Time.current &&
    appointment.status.in?(['confirmed', 'pending']) &&
    appointment.customer&.email.present?
  end

  def appointment_revenue_for_period(appointments, period = nil)
    case period
    when 'today'
      appointments.where(scheduled_at: Date.current.beginning_of_day..Date.current.end_of_day)
    when 'this_week'
      appointments.where(scheduled_at: Date.current.beginning_of_week..Date.current.end_of_week)
    when 'this_month'
      appointments.where(scheduled_at: Date.current.beginning_of_month..Date.current.end_of_month)
    when 'last_month'
      last_month = 1.month.ago
      appointments.where(scheduled_at: last_month.beginning_of_month..last_month.end_of_month)
    else
      appointments
    end.sum(:price)
  end

  def most_booked_session_type(appointments)
    appointments.group(:session_type).count.max_by(&:last)&.first&.humanize || 'No bookings yet'
  end

  def average_appointment_value(appointments)
    return 0 if appointments.empty?
    (appointments.sum(:price) / appointments.count.to_f).round(2)
  end

  def completion_rate(appointments)
    return 0 if appointments.empty?
    completed_count = appointments.where(status: 'completed').count
    ((completed_count.to_f / appointments.count) * 100).round(1)
  end

  def next_available_time_slot
    # This would integrate with your booking system
    # For now, returning a simple suggestion
    if Time.current.hour < 17 # Before 5 PM
      "Today at #{(Time.current + 2.hours).strftime('%I:%M %p')}"
    else
      "Tomorrow at #{Time.current.tomorrow.change(hour: 9).strftime('%I:%M %p')}"
    end
  end

  def appointment_conflicts(appointment)
    # Check for scheduling conflicts
    same_time_appointments = Appointment.where.not(id: appointment.id)
                                       .where(scheduled_at: appointment.scheduled_at)
                                       .where.not(status: ['cancelled', 'no_show'])

    if appointment.user_id.present?
      same_time_appointments = same_time_appointments.where(user_id: appointment.user_id)
    end

    same_time_appointments
  end

  def has_appointment_conflicts?(appointment)
    appointment_conflicts(appointment).exists?
  end

  def working_hours_class(appointment)
    hour = appointment.scheduled_at.hour

    if hour < 8 || hour > 18
      'bg-orange-50 border-orange-200' # Outside normal hours
    else
      'bg-white border-gray-200' # Normal hours
    end
  end

  def customer_appointment_history_summary(customer)
    appointments = customer.appointments.where('scheduled_at < ?', Time.current)

    {
      total_appointments: appointments.count,
      completed_appointments: appointments.where(status: 'completed').count,
      total_spent: appointments.sum(:price),
      favorite_session_type: appointments.group(:session_type).count.max_by(&:last)&.first,
      last_appointment: appointments.order(:scheduled_at).last
    }
  end

  def format_phone_for_display(phone)
    return 'No phone' if phone.blank?

    # Simple US phone formatting
    clean_phone = phone.gsub(/\D/, '')

    if clean_phone.length == 10
      "(#{clean_phone[0..2]}) #{clean_phone[3..5]}-#{clean_phone[6..9]}"
    else
      phone
    end
  end

  def appointment_session_icon(session_type)
    case session_type.to_s.downcase
    when 'portrait'
      '👤'
    when 'wedding'
      '💒'
    when 'family'
      '👨‍👩‍👧‍👦'
    when 'corporate'
      '🏢'
    when 'event'
      '🎉'
    when 'maternity'
      '🤱'
    when 'newborn'
      '👶'
    when 'engagement'
      '💍'
    else
      '📸'
    end
  end
end
