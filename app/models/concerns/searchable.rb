module Searchable
  extend ActiveSupport::Concern

  included do
    def self.search_scope(query)
      return all if query.blank?

      searchkick(
        word_start: [:name, :email],
        searchable: [:name, :email, :description],
        filterable: [:status, :plan_type]
      )

      search(query, fields: [:name, :email, :description])
    end
  end
end
