# spec/controllers/dashboard_controller_spec.rb
require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :confirmed) }
  let!(:tenant_user) { create(:tenant_user, tenant: tenant, user: user, role: 'owner') }

  before do
    sign_in user
    ActsAsTenant.current_tenant = tenant
  end

  describe "GET #index" do
    it "assigns stats and appointments" do
      get :index

      expect(assigns(:stats)).to be_present
      expect(assigns(:recent_appointments)).to be_present
      expect(response).to render_template(:index)
    end

    it "responds to JSON format" do
      get :index, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end
end
