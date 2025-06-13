class ServicePackageStudioLocation < ApplicationRecord
  belongs_to :service_package
  belongs_to :studio_location
end
