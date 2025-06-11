class Rack::Attack
  # Always allow requests from localhost
  safelist('allow from localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  # Rate limiting for API endpoints
  throttle('api requests by ip', limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.starts_with?('/api/')
  end

  # Rate limiting for authentication endpoints
  throttle('login attempts by ip', limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == '/users/sign_in' && req.post?
  end

  throttle('password reset by ip', limit: 5, period: 60.seconds) do |req|
    req.ip if req.path == '/users/password' && req.post?
  end

  # Rate limiting for registration
  throttle('signup by ip', limit: 3, period: 60.seconds) do |req|
    req.ip if req.path == '/signup' && req.post?
  end

  # Exponential backoff for repeated blocked requests
  blocklist('fail2ban pentesters') do |req|
    Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}",
      maxretry: 3,
      findtime: 10.minutes,
      bantime: 5.minutes) do
      CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
      req.path.include?('/etc/passwd') ||
      req.path.include?('wp-admin') ||
      req.path.include?('wp-login')
    end
  end
end

# Configure cache store for rate limiting
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/2'),
  namespace: 'rack_attack'
)
