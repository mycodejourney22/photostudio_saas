class AppointmentsController < ApplicationController
  before_action :set_appointment, only: [:show, :edit, :update, :destroy, :confirm, :cancel]
  load_and_authorize_resource

  def index
    @appointments = current_tenant.appointments
                                 .includes(:customer, :user, :studio)
                                 .page(params[:page])
                                 .per(25)

    @appointments = @appointments.where(status: params[:status]) if params[:status].present?
    @appointments = @appointments.where(session_type: params[:session_type]) if params[:session_type].present?
    @appointments = @appointments.search_scope(params[:search]) if params[:search].present?

    respond_to do |format|
      format.html
      format.json { render json: AppointmentSerializer.new(@appointments).serializable_hash }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: AppointmentSerializer.new(@appointment).serializable_hash }
    end
  end

  def new
    @appointment = current_tenant.appointments.build
    @customers = current_tenant.customers.active.order(:first_name)
    @staff_members = current_tenant.users.joins(:tenant_users)
                                         .where(tenant_users: { role: ['admin', 'staff'] })
  end

  def create
    @appointment = current_tenant.appointments.build(appointment_params)
    @appointment.user = current_user unless @appointment.user_id

    if @appointment.save
      AppointmentConfirmationJob.perform_async(@appointment.id)

      respond_to do |format|
        format.html { redirect_to @appointment, notice: 'Appointment created successfully.' }
        format.json { render json: AppointmentSerializer.new(@appointment).serializable_hash, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new }
        format.json { render json: { errors: @appointment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @appointment.update(appointment_params)
      respond_to do |format|
        format.html { redirect_to @appointment, notice: 'Appointment updated successfully.' }
        format.json { render json: AppointmentSerializer.new(@appointment).serializable_hash }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: { errors: @appointment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def confirm
    if @appointment.update(status: 'confirmed')
      AppointmentConfirmationJob.perform_async(@appointment.id)

      respond_to do |format|
        format.html { redirect_to @appointment, notice: 'Appointment confirmed.' }
        format.json { render json: { status: 'confirmed' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @appointment, alert: 'Unable to confirm appointment.' }
        format.json { render json: { errors: @appointment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def cancel
    if @appointment.can_be_cancelled? && @appointment.update(status: 'cancelled')
      respond_to do |format|
        format.html { redirect_to appointments_path, notice: 'Appointment cancelled.' }
        format.json { render json: { status: 'cancelled' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @appointment, alert: 'Unable to cancel appointment.' }
        format.json { render json: { error: 'Cannot cancel appointment' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_appointment
    @appointment = current_tenant.appointments.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :customer_id, :user_id, :studio_id, :scheduled_at, :duration_minutes,
      :price, :session_type, :notes, :special_requirements
    )
  end
end
