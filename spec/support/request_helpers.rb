# spec/support/request_helpers.rb
module RequestHelpers
  def json_response
    JSON.parse(response.body)
  end

  def authenticate_request(user)
    sign_in user
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
