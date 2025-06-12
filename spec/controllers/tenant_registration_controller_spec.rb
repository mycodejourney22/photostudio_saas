require 'rails_helper'

RSpec.describe TenantRegistrationController, type: :controller do
  describe "POST #create" do
    let(:valid_params) do
      {
        tenant: {
          name: "Test Studio",
          subdomain: "test-studio",
          email: "test@studio.com"
        },
        user: {
          first_name: "John",
          last_name: "Doe",
          email: "john@studio.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    it "creates tenant and user with valid params" do
      expect {
        post :create, params: valid_params
      }.to change(Tenant, :count).by(1)
        .and change(User, :count).by(1)
        .and change(TenantUser, :count).by(1)
    end

    it "sends verification email" do
      expect {
        post :create, params: valid_params
      }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

    it "redirects to success page" do
      post :create, params: valid_params

      tenant = Tenant.last
      expect(response).to redirect_to(tenant_registration_success_path(token: tenant.verification_token))
    end
  end

  describe "GET #verify" do
    let(:tenant) { create(:tenant, status: 'pending') }

    it "verifies tenant with valid token" do
      get :verify, params: { token: tenant.verification_token }

      tenant.reload
      expect(tenant.status).to eq('active')
      expect(response).to render_template(:verified)
    end

    it "redirects with invalid token" do
      get :verify, params: { token: 'invalid-token' }

      expect(response).to redirect_to(new_tenant_registration_path)
      expect(flash[:alert]).to be_present
    end
  end
end
