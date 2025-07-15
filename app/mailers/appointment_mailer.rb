# app/mailers/appointment_mailer.rb
require 'jwt'

class AppointmentMailer < ApplicationMailer
  include TenantMailerConcern
  include Rails.application.routes.url_helpers
  include Rails.application.routes.mounted_helpers

  def confirmation_email(appointment)
    @appointment = appointment
    @customer = appointment.customer
    @tenant = appointment.tenant
    @service_tier = appointment.service_tier
    @service_package = appointment.service_package
    @studio_location = appointment.studio_location

    setup_tenant_mailer(@tenant)

    @cancellation_url = booking_public_booking_cancel_url(
      tenant_slug: @tenant.subdomain,
      appointment_id: @appointment.id,
      token: generate_cancellation_token(@appointment),
      host: Rails.env.production? ? "shuttersuites.co" : "localhost:3000",
      protocol: Rails.env.production? ? "https" : "http"
    )

    @reschedule_url = booking_public_booking_reschedule_url(
      @tenant.subdomain,
      appointment_id: @appointment.id,
      token: generate_reschedule_token(@appointment),
      host: Rails.env.production? ? "shuttersuites.co" : "localhost:3000",
      protocol: Rails.env.production? ? "https" : "http"
    )

    mail(
      to: @customer.email,
      subject: appointment_confirmation_subject,
      template_name: 'confirmation_email'
    )
  end

  def reminder_email(appointment, reminder_type = '24_hours')
    @appointment = appointment
    @customer = appointment.customer
    @tenant = appointment.tenant
    @service_tier = appointment.service_tier
    @studio_location = appointment.studio_location
    @reminder_type = reminder_type

    setup_tenant_mailer(@tenant)

    @preparation_tips = get_preparation_tips(@appointment.session_type)
    @contact_info = @tenant.email_settings.dig('contact_info') || default_contact_info

    @reschedule_url = booking_public_booking_reschedule_url(
      @tenant.subdomain,
      appointment_id: @appointment.id,
      token: generate_reschedule_token(@appointment),
      host: Rails.env.production? ? "shuttersuites.co" : "localhost:3000",
      protocol: Rails.env.production? ? "https" : "http"
    )

    mail(
      to: @customer.email,
      subject: appointment_reminder_subject(reminder_type),
      template_name: 'reminder_email'
    )
  end

  def feedback_request_email(appointment)
    @appointment = appointment
    @customer = appointment.customer
    @tenant = appointment.tenant
    @service_tier = appointment.service_tier

    setup_tenant_mailer(@tenant)

    @feedback_url = public_feedback_url(
      @tenant.subdomain,
      appointment_id: @appointment.id,
      token: generate_feedback_token(@appointment),
      host: @tenant.full_domain
    )

    @gallery_url = if @appointment.gallery_ready?
      public_gallery_url(
        @tenant.subdomain,
        appointment_id: @appointment.id,
        token: generate_gallery_token(@appointment),
        host: @tenant.full_domain
      )
    end

    mail(
      to: @customer.email,
      subject: feedback_request_subject,
      template_name: 'feedback_request_email'
    )
  end

  def status_update_email(appointment, previous_status)
    @appointment = appointment
    @customer = appointment.customer
    @tenant = appointment.tenant
    @previous_status = previous_status
    @current_status = appointment.status

    setup_tenant_mailer(@tenant)

    mail(
      to: @customer.email,
      subject: status_update_subject,
      template_name: 'status_update_email'
    )
  end

  # def default_url_options
  #   protocol = Rails.env.production? ? 'https' : 'http'
  #   { host: @tenant.full_domain, protocol: protocol }
  # end

  private

 

  def appointment_confirmation_subject
    studio_name = @tenant.name
    date = @appointment.scheduled_at.strftime('%B %d, %Y')
    "#{studio_name} - Appointment Confirmed for #{date}"
  end

  def appointment_reminder_subject(reminder_type)
    studio_name = @tenant.name
    case reminder_type
    when '24_hours'
      "#{studio_name} - Your session is tomorrow!"
    when '2_hours'
      "#{studio_name} - Your session starts soon"
    when '1_week'
      "#{studio_name} - Session reminder for next week"
    else
      "#{studio_name} - Session reminder"
    end
  end

  def feedback_request_subject
    "How was your experience with #{@tenant.name}? Share your feedback"
  end

  def status_update_subject
    case @current_status
    when 'confirmed'
      "#{@tenant.name} - Your appointment has been confirmed"
    when 'in_progress'
      "#{@tenant.name} - Your photoshoot is underway"
    when 'completed'
      "#{@tenant.name} - Your session is complete!"
    when 'cancelled'
      "#{@tenant.name} - Appointment cancellation notice"
    else
      "#{@tenant.name} - Appointment update"
    end
  end

  def get_preparation_tips(session_type)
    case session_type.to_s
    when 'portrait'
      [
        'Avoid busy patterns or logos on clothing',
        'Bring a few outfit options',
        'Get plenty of rest the night before',
        'Arrive 10 minutes early to settle in'
      ]
    when 'family'
      [
        'Coordinate colors but avoid matching exactly',
        'Bring snacks and small toys for children',
        'Plan the session around nap times',
        'Consider bringing a change of clothes for kids'
      ]
    when 'wedding'
      [
        'Bring any special jewelry or accessories',
        'Confirm hair and makeup timing',
        'Have emergency contact info available',
        'Arrive early for setup and preparation'
      ]
    else
      [
        'Arrive on time for your session',
        'Bring any requested items or props',
        'Feel free to ask questions during the shoot',
        'Relax and have fun!'
      ]
    end
  end

  def default_contact_info
    {
      'phone' => @tenant.phone || 'Contact via email',
      'email' => @tenant.email,
      'address' => @studio_location&.address || 'See appointment details'
    }
  end

  def generate_cancellation_token(appointment)
    payload = {
      appointment_id: appointment.id,
      customer_email: appointment.customer.email,
      action: 'cancel',
      expires_at: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def generate_reschedule_token(appointment)
    payload = {
      appointment_id: appointment.id,
      customer_email: appointment.customer.email,
      action: 'reschedule',
      expires_at: 7.days.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def generate_feedback_token(appointment)
    payload = {
      appointment_id: appointment.id,
      customer_email: appointment.customer.email,
      action: 'feedback',
      expires_at: 30.days.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def generate_gallery_token(appointment)
    payload = {
      appointment_id: appointment.id,
      customer_email: appointment.customer.email,
      action: 'gallery',
      expires_at: 90.days.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
end
