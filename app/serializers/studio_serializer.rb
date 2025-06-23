class StudioSerializer < ApplicationSerializer
  attributes :id, :name, :address, :city, :state, :zip_code, :phone,
             :description, :active, :created_at

  attribute :full_address do |studio|
    [studio.address, studio.city, studio.state, studio.zip_code].compact.join(', ')
  end

  attribute :image_url do |studio|
    if studio.image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(studio.image)
    end
  end
end
