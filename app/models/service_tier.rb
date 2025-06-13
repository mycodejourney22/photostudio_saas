# app/models/service_tier.rb
class ServiceTier < ApplicationRecord
  belongs_to :service_package
  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :price) }

  def tenant
    service_package.tenant
  end

  def formatted_price
    "$#{price.to_i}"
  end

  def duration_hours
    duration_minutes / 60.0
  end

  def duration_display
    if duration_minutes >= 60
      hours = duration_minutes / 60
      minutes = duration_minutes % 60
      if minutes > 0
        "#{hours}h #{minutes}m"
      else
        "#{hours}h"
      end
    else
      "#{duration_minutes}m"
    end
  end

  def features_list
    features.is_a?(Array) ? features : []
  end

  def add_feature(feature)
    self.features = features_list + [feature]
  end

  def remove_feature(feature)
    self.features = features_list - [feature]
  end
end
