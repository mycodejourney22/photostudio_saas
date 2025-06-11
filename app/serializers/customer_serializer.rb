class CustomerSerializer < ApplicationSerializer
  attributes :id, :first_name, :last_name, :email, :phone,
             :address, :city, :state, :zip_code, :created_at

  has_many :appointments, serializer: AppointmentSerializer

  attribute :full_name do |customer|
    customer.full_name
  end

  attribute :total_bookings do |customer|
    customer.total_bookings
  end

  attribute :total_revenue do |customer|
    customer.total_revenue
  end

  attribute :profile_image_url do |customer|
    if customer.profile_image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(customer.profile_image)
    end
  end
end
