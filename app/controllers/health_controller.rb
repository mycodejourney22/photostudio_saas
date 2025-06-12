# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_tenant

  def check
    # Basic health checks
    checks = {
      database: database_check,
      redis: redis_check,
      timestamp: Time.current.iso8601
    }

    status = checks.values.all? ? :ok : :service_unavailable

    render json: {
      status: status == :ok ? 'healthy' : 'unhealthy',
      checks: checks
    }, status: status
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    'healthy'
  rescue => e
    Rails.logger.error "Database health check failed: #{e.message}"
    'unhealthy'
  end

  def redis_check
    if defined?(Redis)
      Redis.current.ping
      'healthy'
    else
      'not_configured'
    end
  rescue => e
    Rails.logger.error "Redis health check failed: #{e.message}"
    'unhealthy'
  end
end
