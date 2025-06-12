require_relative "boot"

require "rails/all"# Pick the frameworks you want:


# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PhotostudioSaas
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))
    config.autoload_paths << Rails.root.join('lib', 'constraints')


    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '/api/*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: false
      end
    end

    # Active Job configuration
    config.active_job.queue_adapter = :sidekiq

    # Time zone
    config.time_zone = 'UTC'

    # Domain configuration
    config.app_domain = ENV.fetch('APP_DOMAIN', 'photostudio.local')
    config.main_domain = ENV.fetch('MAIN_DOMAIN', 'www.photostudio.com')
    config.action_controller.raise_on_open_redirects = false



     config.active_storage.variant_processor = :image_processing
    config.active_storage.analyzers.delete ActiveStorage::Analyzer::VideoAnalyzer

    # Security configurations
    config.force_ssl = Rails.env.production?
    config.ssl_options = {
      redirect: { exclude: ->(request) { request.path =~ /health/ } }
    }

    # Custom configurations
    config.max_file_size = 10.megabytes
    config.allowed_file_types = %w[image/jpeg image/png image/webp image/gif]

    # Pagination defaults
    config.default_per_page = 25
    config.max_per_page = 100

    # Rate limiting (using Rack::Attack)
    config.middleware.use Rack::Attack

  end
end
