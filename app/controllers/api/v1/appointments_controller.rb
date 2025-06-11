class Api::V1::AppointmentsController < Api::BaseController
  before_action :set_appointment, only: [:show, :update, :destroy]

  def index
    @appointments = current_tenant.appointments
                                 .includes(:customer, :user, :studio)
                                 .page(params[:page])
                                 .per(params[:per_page] || 25)

    apply_filters

    render json: {
      data: AppointmentSerializer.new(@appointments).serializable_hash[:data],
      meta: pagination_meta(@appointments)
    }
  end

  def show
    render json: AppointmentSerializer.new(@appointment).serializable_hash
  end

  def create
    @appointment = current_tenant.appointments.build(appointment_params)
    @appointment.user = current_user unless @appointment.user_id

    if @appointment.save
      render json: AppointmentSerializer.new(@appointment).serializable_hash, status: :created
    else
      render_validation_errors(@appointment)
    end
  end

  def update
    if @appointment.update(appointment_params)
      render json: AppointmentSerializer.new(@appointment).serializable_hash
    else
      render_validation_errors(@appointment)
    end
  end

  def destroy
    @appointment.destroy
    head :no_content
  end

  private

  def set_appointment
    @appointment = current_tenant.appointments.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :customer_id, :user_id, :studio_id, :scheduled_at,
      :duration_minutes, :price, :session_type, :notes
    )
  end

  def apply_filters
    @appointments = @appointments.where(status: params[:status]) if params[:status].present?
    @appointments = @appointments.where(session_type: params[:session_type]) if params[:session_type].present?
    @appointments = @appointments.where('scheduled_at >= ?', params[:start_date]) if params[:start_date].present?
    @appointments = @appointments.where('scheduled_at <= ?', params[:end_date]) if params[:end_date].present?
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
