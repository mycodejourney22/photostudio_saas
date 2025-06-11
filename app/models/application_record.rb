class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  include Searchable
  include Trackable

  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }
end
