# Replace your config/initializers/sidekiq.rb with this (without Cron):

# Sidekiq 7+ configuration (namespaces are no longer supported)
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  }

  # Remove Cron functionality for now - you can add it back later if needed
  # schedule_file = "config/sidekiq_cron.yml"
  # if File.exist?(schedule_file)
  #   Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  # end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  }
end

# Optional: Configure Sidekiq concurrency
Sidekiq.configure_server do |config|
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 5).to_i
end
