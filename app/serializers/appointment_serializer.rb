class AppointmentSerializer < ApplicationSerializer
  attributes :id, :scheduled_at, :duration_minutes, :price, :session_type,
             :status, :notes, :created_at, :updated_at

  belongs_to :customer
  belongs_to :user, serializer: UserSerializer
  belongs_to :studio, serializer: StudioSerializer

  attribute :end_time do |appointment|
    appointment.end_time
  end

  attribute :customer_name do |appointment|
    appointment.customer.full_name
  end

  attribute :staff_name do |appointment|
    appointment.user.full_name
  end

  attribute :can_be_cancelled do |appointment|
    appointment.can_be_cancelled?
  end
end
