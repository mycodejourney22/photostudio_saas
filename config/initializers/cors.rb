Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      /\Ahttps?:\/\/.*\.#{Regexp.escape(ENV.fetch('APP_DOMAIN', 'photostudio.local'))}\z/,
      /\Ahttps?:\/\/#{Regexp.escape(ENV.fetch('MAIN_DOMAIN', 'localhost:3000'))}\z/
    )

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 86400
  end

  # Allow mobile app access
  allow do
    origins '*'
    resource '/mobile/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end
