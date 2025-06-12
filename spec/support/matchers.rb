# spec/support/matchers.rb
RSpec::Matchers.define :have_error_on do |field|
  match do |model|
    model.valid?
    model.errors[field].any?
  end

  failure_message do |model|
    "expected #{model.class.name} to have error on #{field}, but it didn't"
  end
end

RSpec::Matchers.define :be_valid_tenant do
  match do |tenant|
    tenant.valid? &&
    tenant.subdomain.present? &&
    tenant.email.present? &&
    tenant.name.present?
  end

  failure_message do |tenant|
    "expected #{tenant.inspect} to be a valid tenant"
  end
end
