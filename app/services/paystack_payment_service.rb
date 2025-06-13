# app/services/paystack_payment_service.rb
class PaystackPaymentService
  attr_reader :appointment, :paystack_client

  def initialize(appointment = nil)
    @appointment = appointment
    @paystack_client = Paystack.new(Rails.application.credentials.paystack[:secret_key])
  end

  def initialize_payment
    return false unless appointment

    reference = generate_reference

    payment_data = {
      email: appointment.customer.email,
      amount: (appointment.price * 100).to_i, # Convert to kobo
      reference: reference,
      callback_url: Rails.application.routes.url_helpers.booking_payment_callback_url(
        subdomain: appointment.tenant.subdomain,
        host: Rails.application.config.app_domain
      ),
      metadata: {
        appointment_id: appointment.id,
        customer_name: appointment.customer.full_name,
        service: "#{appointment.service_package_name} - #{appointment.service_tier_name}",
        studio_location: appointment.location_name
      },
      channels: ['card', 'bank', 'ussd', 'qr', 'mobile_money', 'bank_transfer']
    }

    begin
      response = paystack_client.transaction.initialize(payment_data)

      if response[:status]
        # Store payment reference in appointment metadata
        appointment.update!(
          metadata: appointment.metadata.merge(
            paystack_reference: reference,
            payment_initialized_at: Time.current
          )
        )

        @authorization_url = response[:data][:authorization_url]
        true
      else
        Rails.logger.error "Paystack initialization failed: #{response[:message]}"
        false
      end
    rescue => e
      Rails.logger.error "Paystack error: #{e.message}"
      false
    end
  end

  def authorization_url
    @authorization_url
  end

  def verify_payment(reference)
    begin
      response = paystack_client.transaction.verify(reference)

      if response[:status] && response[:data][:status] == 'success'
        appointment = find_appointment_by_reference(reference)

        if appointment
          update_appointment_payment_status(appointment, response[:data])
          true
        else
          Rails.logger.error "Appointment not found for reference: #{reference}"
          false
        end
      else
        Rails.logger.error "Payment verification failed: #{response[:message]}"
        false
      end
    rescue => e
      Rails.logger.error "Payment verification error: #{e.message}"
      false
    end
  end

  def refund_payment(appointment, amount = nil)
    return false unless appointment.metadata['paystack_reference']

    refund_amount = amount || appointment.paid_amount

    refund_data = {
      transaction: appointment.metadata['paystack_reference'],
      amount: (refund_amount * 100).to_i # Convert to kobo
    }

    begin
      response = paystack_client.refund.create(refund_data)

      if response[:status]
        appointment.update!(
          payment_status: 'refunded',
          status: 'cancelled',
          metadata: appointment.metadata.merge(
            refund_reference: response[:data][:reference],
            refunded_at: Time.current,
            refund_amount: refund_amount
          )
        )
        true
      else
        Rails.logger.error "Refund failed: #{response[:message]}"
        false
      end
    rescue => e
      Rails.logger.error "Refund error: #{e.message}"
      false
    end
  end

  def payment_status(reference)
    begin
      response = paystack_client.transaction.verify(reference)
      response[:data][:status] if response[:status]
    rescue => e
      Rails.logger.error "Status check error: #{e.message}"
      nil
    end
  end

  private

  def generate_reference
    "#{appointment.tenant.subdomain}_#{appointment.id}_#{SecureRandom.hex(8)}"
  end

  def find_appointment_by_reference(reference)
    # Extract tenant subdomain and appointment ID from reference
    parts = reference.split('_')
    return nil unless parts.length >= 2

    subdomain = parts[0]
    appointment_id = parts[1]

    tenant = Tenant.find_by(subdomain: subdomain)
    return nil unless tenant

    tenant.appointments.find_by(id: appointment_id)
  end

  def update_appointment_payment_status(appointment, payment_data)
    appointment.update!(
      payment_status: 'paid',
      status: 'confirmed',
      paid_amount: payment_data[:amount] / 100.0, # Convert from kobo
      metadata: appointment.metadata.merge(
        payment_verified_at: Time.current,
        paystack_transaction_id: payment_data[:id],
        paystack_gateway_response: payment_data[:gateway_response],
        payment_channel: payment_data[:channel]
      )
    )
  end
end
