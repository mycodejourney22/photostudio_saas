module SetupValidations
  extend ActiveSupport::Concern

  included do
    validates :name, presence: true
    validates :name, length: { minimum: 2, maximum: 100 }
  end

  class_methods do
    def setup_complete?
      all.exists?
    end

    def setup_progress
      {
        configured: all.count,
        required: 1,
        percentage: all.exists? ? 100 : 0
      }
    end
  end
end
