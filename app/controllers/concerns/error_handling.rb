module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  end

  private

  def handle_standard_error(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    respond_to do |format|
      format.json { render json: { error: 'Internal server error' }, status: :internal_server_error }
      format.html { render 'errors/500', status: :internal_server_error }
    end
  end

  def handle_not_found(exception)
    respond_to do |format|
      format.json { render json: { error: 'Resource not found' }, status: :not_found }
      format.html { render 'errors/404', status: :not_found }
    end
  end

  def handle_parameter_missing(exception)
    respond_to do |format|
      format.json { render json: { error: exception.message }, status: :bad_request }
      format.html { redirect_back(fallback_location: root_path, alert: exception.message) }
    end
  end
end
