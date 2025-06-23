class UserSerializer < ApplicationSerializer
  attributes :id, :first_name, :last_name, :email, :phone, :active, :created_at

  attribute :full_name do |user|
    user.full_name
  end

  attribute :role do |user|
    user.role_in_tenant(current_tenant) if respond_to?(:current_tenant) && current_tenant
  end

  attribute :avatar_url do |user|
    if user.avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_url(user.avatar)
    end
  end
end
