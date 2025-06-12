class ApplicationJob < ActiveJob::Base
  # include Sidekiq::Job

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  around_perform do |job, block|
    tenant = job.arguments.first if job.arguments.first.is_a?(Tenant)

    if tenant
      ActsAsTenant.with_tenant(tenant) { block.call }
    else
      block.call
    end
  end
end
