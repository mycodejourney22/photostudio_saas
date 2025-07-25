require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # custom design
  config.cache_classes = true


  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  config.assets.digest = true


  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id, :subdomain]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
   config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    namespace: 'photostudio'
  }

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :smtp
  # DEFAULT/FALLBACK SMTP Configuration


  # Use Heroku add-ons for default SMTP or set fallback SMTP
  if ENV['SENDGRID_USERNAME'].present?
    # SendGrid addon is available
    config.action_mailer.smtp_settings = {
      port: ENV.fetch('SENDGRID_SMTP_PORT', 587),
      address: 'smtp.sendgrid.net',
      user_name: ENV['SENDGRID_USERNAME'],
      password: ENV['SENDGRID_PASSWORD'],
      domain: ENV.fetch('APP_DOMAIN', 'shuttersuites-638880348a66.herokuapp.com'),
      authentication: :plain,
      enable_starttls_auto: true
    }
  elsif ENV['MAILGUN_SMTP_LOGIN'].present?
    # Mailgun addon is available
    config.action_mailer.smtp_settings = {
      port: ENV.fetch('MAILGUN_SMTP_PORT', 587),
      address: ENV.fetch('MAILGUN_SMTP_SERVER', 'smtp.mailgun.org'),
      user_name: ENV['MAILGUN_SMTP_LOGIN'],
      password: ENV['MAILGUN_SMTP_PASSWORD'],
      domain: ENV.fetch('APP_DOMAIN', 'shuttersuites-638880348a66.herokuapp.com'),
      authentication: :plain,
      enable_starttls_auto: true
    }
  elsif ENV['SMTP_HOST'].present?
    # Custom SMTP environment variables are set
    config.action_mailer.smtp_settings = {
      address: ENV.fetch('SMTP_HOST'),
      port: ENV.fetch('SMTP_PORT', 587),
      domain: ENV.fetch('SMTP_DOMAIN', ENV.fetch('APP_DOMAIN', 'shuttersuites-638880348a66.herokuapp.com')),
      user_name: ENV.fetch('SMTP_USERNAME'),
      password: ENV.fetch('SMTP_PASSWORD'),
      authentication: 'plain',
      enable_starttls_auto: true
    }
  else
    # Minimal fallback SMTP configuration
    # This allows the app to start even without SMTP configured
    config.action_mailer.smtp_settings = {
      address: 'localhost',
      port: 587,
      domain: ENV.fetch('APP_DOMAIN', 'shuttersuites-638880348a66.herokuapp.com'),
      authentication: :plain,
      enable_starttls_auto: true
    }

    # In development/testing, you might want to use :test delivery method
    # config.action_mailer.delivery_method = :test if Rails.env.development?
  end

  config.action_mailer.default_url_options = {
    host: ENV.fetch('APP_DOMAIN', 'shuttersuites-638880348a66.herokuapp.com'),
    protocol: 'https'
  }

  Rails.application.routes.default_url_options = {
    host: ENV.fetch('APP_DOMAIN', 'shuttersuites-638880348a66.herokuapp.com'),
    protocol: 'https'
  }

  # Security headers
  config.force_ssl = true
  config.ssl_options = {
    secure_cookies: true,
    hsts: {
      expires: 1.year,
      include_subdomains: true,
      preload: true
    }
  }

  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, 'https://*.amazonaws.com'
    policy.object_src  :none
    policy.script_src  :self, :https, 'https://js.stripe.com'
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, 'https://api.stripe.com'
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Exception handling
  config.consider_all_requests_local = false
  config.action_controller.raise_on_missing_callback_actions = false


  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "photostudio_saas_production"

  config.action_mailer.perform_caching = false

  config.active_storage.service = :production


  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
