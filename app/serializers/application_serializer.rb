class ApplicationSerializer
  include JSONAPI::Serializer

  def self.current_tenant
    ActsAsTenant.current_tenant
  end
end
