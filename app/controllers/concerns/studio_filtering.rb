# app/controllers/concerns/studio_filtering.rb - UPDATED VERSION
module StudioFiltering
  extend ActiveSupport::Concern

  private

  # Generic method to filter any relation by studio access
  def filter_by_studio_access(relation, studio_column = :studio_location_id)
    return relation if current_user.can_access_all_studios?(current_tenant)

    # FIXED: Handle Array vs ActiveRecord relation issue
    accessible_studios = current_user.accessible_studio_locations(current_tenant)
    accessible_studio_ids = accessible_studios.is_a?(Array) ? accessible_studios.map(&:id) : accessible_studios.pluck(:id)

    return relation.none if accessible_studio_ids.empty?

    relation.where(studio_column => accessible_studio_ids)
  end

  # Specific method for filtering expenses
  def filter_expenses_by_studio_access(expenses_relation)
    filter_by_studio_access(expenses_relation, :studio_location_id)
  end

  # Specific method for filtering appointments
  def filter_appointments_by_studio_access(appointments_relation)
    filter_by_studio_access(appointments_relation, :studio_location_id)
  end

  # Specific method for filtering sales
  def filter_sales_by_studio_access(sales_relation)
    filter_by_studio_access(sales_relation, :studio_location_id)
  end

  # Helper methods for current user's studio access
  def current_user_accessible_studios
    @current_user_accessible_studios ||= current_user.accessible_studio_locations(current_tenant)
  end

  # FIXED: Get ordered studios handling both Array and ActiveRecord relation
  def current_user_accessible_studios_ordered
    studios = current_user_accessible_studios
    if studios.is_a?(Array)
      studios.sort_by(&:name)
    else
      studios.order(:name)
    end
  end

  def current_user_can_access_all_studios?
    current_user.can_access_all_studios?(current_tenant)
  end

  # Generic scoped collection method for any model
  def studio_scoped_collection(model_class, studio_column = :studio_location_id)
    collection = current_tenant.send(model_class.table_name)
    filter_by_studio_access(collection, studio_column)
  end

  # Get user's default studio for forms
  def current_user_default_studio
    staff_member = current_user.current_staff_member(current_tenant)
    staff_member&.studio_location || current_tenant.studio_locations.first
  end

  # Check if user can access a specific studio
  def can_access_studio?(studio_location)
    return true if current_user_can_access_all_studios?
    current_user_accessible_studios.include?(studio_location)
  end

  # Method to validate studio access for form submissions
  def validate_studio_access!(studio_location_id)
    return true if current_user_can_access_all_studios?

    accessible_studio_ids = current_user_accessible_studios.pluck(:id)
    unless accessible_studio_ids.include?(studio_location_id.to_i)
      raise CanCan::AccessDenied, "You don't have access to this studio location"
    end
  end
end
