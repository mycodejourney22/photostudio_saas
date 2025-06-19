# app/controllers/admin/email_settings_controller.rb
class Admin::EmailSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access!

  def show
    @tenant = current_tenant
    @smtp_test_result = session.delete(:smtp_test_result)
  end

  def update
    @tenant = current_tenant

    success = true

    # Update email settings
    if params[:tenant][:email_settings].present?
      success &= update_email_settings
    end

    # Update SMTP settings
    if params[:tenant][:smtp_settings].present?
      success &= update_smtp_settings
    end

    if success
      redirect_to admin_email_settings_path, notice: 'Email settings updated successfully!'
    else
      flash.now[:alert] = 'There was an error updating your email settings.'
      render :show, status: :unprocessable_entity
    end
  end

  def test_smtp
    @tenant = current_tenant

    if @tenant.smtp_configured?
      result = @tenant.test_smtp_connection

      if result[:success]
        # Send actual test email
        begin
          TestMailer.smtp_test(@tenant).deliver_now
          session[:smtp_test_result] = { success: true, message: 'Test email sent successfully!' }
        rescue => e
          session[:smtp_test_result] = { success: false, message: "Failed to send test email: #{e.message}" }
        end
      else
        session[:smtp_test_result] = result
      end
    else
      session[:smtp_test_result] = { success: false, message: 'SMTP is not configured' }
    end

    redirect_to admin_email_settings_path
  end

  def reset_smtp
    current_tenant.update!(smtp_settings: {}, mailer_enabled: false)
    redirect_to admin_email_settings_path, notice: 'SMTP settings have been reset.'
  end

  private

  def update_email_settings
    # Directly update with the nested email_settings hash
    email_settings = params[:tenant][:email_settings]

    # Convert string values to appropriate types
    processed_settings = process_email_settings(email_settings)

    current_tenant.update(email_settings: processed_settings)
  end

  def update_smtp_settings
    smtp_settings = params[:tenant][:smtp_settings]

    # Check if any meaningful SMTP data was provided
    has_smtp_data = smtp_settings.values.any? { |v| v.present? && v != "false" }

    if has_smtp_data
      # Remove blank values and process
      processed_smtp = smtp_settings.reject { |k, v| v.blank? }
      processed_smtp['port'] = processed_smtp['port'].to_i if processed_smtp['port']
      processed_smtp['ssl'] = processed_smtp['ssl'] == 'true'

      # Only enable if we have at least a host
      if processed_smtp['host'].present?
        current_tenant.update(smtp_settings: processed_smtp, mailer_enabled: true)
      else
        # Save the settings but don't enable yet
        current_tenant.update(smtp_settings: processed_smtp, mailer_enabled: false)
      end
    else
      # Clear everything if no data provided
      current_tenant.update(smtp_settings: {}, mailer_enabled: false)
    end

    true
  end

  def process_email_settings(settings)
    processed = settings.dup

    # Convert string booleans to actual booleans
    ['send_confirmations', 'send_reminders', 'send_feedback_requests'].each do |key|
      processed[key] = processed[key] == 'true' if processed[key].present?
    end

    # Convert feedback delay to integer
    processed['feedback_delay_hours'] = processed['feedback_delay_hours'].to_i if processed['feedback_delay_hours']

    # Process reminder schedule
    if processed['reminder_schedule'].present?
      processed['reminder_schedule'].transform_values! { |v| v == 'true' }

      # Map the form field names to internal names
      reminder_mapping = {
        'one_week' => '1_week',
        'twenty_four_hours' => '24_hours',
        'two_hours' => '2_hours'
      }

      new_schedule = {}
      processed['reminder_schedule'].each do |key, value|
        internal_key = reminder_mapping[key] || key
        new_schedule[internal_key] = value
      end
      processed['reminder_schedule'] = new_schedule
    end

    processed
  end

  def ensure_admin_access!
    # Check if user has admin access to this tenant
    return if current_user.super_admin?

    tenant_user = current_user.tenant_users.find_by(tenant: current_tenant)
    unless tenant_user&.role&.in?(['owner', 'admin'])
      redirect_to dashboard_path, alert: 'Access denied. Admin privileges required.'
    end
  end
end
