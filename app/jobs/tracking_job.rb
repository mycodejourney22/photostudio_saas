class TrackingJob < ApplicationJob
  queue_as :default

  def perform(resource_class, resource_id, action, metadata = {})
    Rails.logger.info "Tracking: #{resource_class}##{resource_id} - #{action}"
    Rails.logger.info "Metadata: #{metadata}" if metadata.any?
    
    # Add your actual tracking logic here
    # For example, send to analytics service, log to database, etc.
  end
end
