class TrackingService
  def self.track_event(resource, action, metadata = {})
    return unless Rails.env.production?

    TrackingJob.perform_async(
      resource.class.name,
      resource.id,
      action,
      metadata
    )
  end
end
