Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    namespace: 'photostudio_sidekiq'
  }

  # Cron jobs
  schedule_file = "config/sidekiq_cron.yml"
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    namespace: 'photostudio_sidekiq'
  }
end
