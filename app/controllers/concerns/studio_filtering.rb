module StudioFiltering
  extend ActiveSupport::Concern

  private

  def filter_by_studio_access(relation, studio_column = :studio_location_id)
    return relation if current_user.can_access_all_studios?(current_tenant)

    accessible_studio_ids = current_user.accessible_studio_locations(current_tenant).pluck(:id)
    return relation.none if accessible_studio_ids.empty?

    relation.where(studio_column => accessible_studio_ids)
  end

  def current_user_accessible_studios
    @current_user_accessible_studios ||= current_user.accessible_studio_locations(current_tenant)
  end

  def studio_scoped_collection(model_class, studio_column = :studio_location_id)
    collection = current_tenant.send(model_class.table_name)
    filter_by_studio_access(collection, studio_column)
  end

  def current_user_default_studio
    staff_member = current_user.current_staff_member(current_tenant)
    staff_member&.studio_location || current_tenant.studio_locations.first
  end
end
