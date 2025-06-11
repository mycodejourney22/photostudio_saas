module Trackable
  extend ActiveSupport::Concern

  included do
    before_create :set_uuid
    after_create :track_creation
    after_update :track_updates

    private

    def set_uuid
      self.uuid = SecureRandom.uuid if respond_to?(:uuid) && uuid.blank?
    end

    def track_creation
      TrackingService.track_event(self, 'created')
    end

    def track_updates
      TrackingService.track_event(self, 'updated') if saved_changes.any?
    end
  end
end
