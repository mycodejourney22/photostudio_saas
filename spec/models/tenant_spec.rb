# spec/models/tenant_spec.rb (Enhanced)
require 'rails_helper'

RSpec.describe Tenant, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:subdomain) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:subdomain) }
  end

  describe "associations" do
    it { should have_many(:tenant_users) }
    it { should have_many(:users).through(:tenant_users) }
    it { should have_many(:customers) }
    it { should have_many(:appointments) }
    it { should have_many(:studios) }
    it { should have_one(:branding) }
  end

  describe "callbacks" do
    it "generates verification token before creation" do
      tenant = build(:tenant)
      expect(tenant.verification_token).to be_nil

      tenant.save!
      expect(tenant.verification_token).to be_present
    end

    it "creates default branding after creation" do
      tenant = create(:tenant)
      expect(tenant.branding).to be_present
      expect(tenant.branding.primary_color).to eq('#667eea')
    end
  end

  describe "#verify!" do
    it "activates tenant and clears verification token" do
      tenant = create(:tenant, status: 'pending')

      tenant.verify!

      expect(tenant.status).to eq('active')
      expect(tenant.verified_at).to be_present
      expect(tenant.verification_token).to be_nil
    end
  end

  describe "#full_domain" do
    it "returns full domain with subdomain" do
      tenant = build(:tenant, subdomain: 'test-studio')
      expect(tenant.full_domain).to include('test-studio')
    end
  end
end
