class CustomersController < ApplicationController
  include StudioFiltering
  before_action :set_customer, only: [:show,  :update, :destroy]
  load_and_authorize_resource

  def index
    # @customers = current_tenant.customers
    #                           .includes(:appointments)
    #                           .page(params[:page])
    #                           .per(25)
    @customers = filter_customer_access(@customers)
              .includes(:appointments)
              .page(params[:page])

    @customers = @customers.search_scope(params[:search]) if params[:search].present?
    @customers = @customers.with_recent_bookings if params[:recent_bookings] == 'true'

    respond_to do |format|
      format.html
      format.json { render json: CustomerSerializer.new(@customers).serializable_hash }
    end
  end

  # def edit
  # end

  def show
    @appointments = @customer.appointments.includes(:user, :studio).recent.limit(10)
    @stats = {
      total_bookings: @customer.total_bookings,
      total_revenue: @customer.total_revenue,
      last_appointment: @customer.last_appointment&.scheduled_at
    }

    respond_to do |format|
      format.html
      format.json { render json: CustomerSerializer.new(@customer, include: [:appointments]).serializable_hash }
    end
  end

  def new
    @customer = current_tenant.customers.build
  end

  def create
    @customer = current_tenant.customers.build(customer_params)

    if @customer.save
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Customer created successfully.' }
        format.json { render json: CustomerSerializer.new(@customer).serializable_hash, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new }
        format.json { render json: { errors: @customer.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @customer.update(customer_params)
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Customer updated successfully.' }
        format.json { render json: CustomerSerializer.new(@customer).serializable_hash }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: { errors: @customer.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @customer.destroy

    respond_to do |format|
      format.html { redirect_to customers_path, notice: 'Customer deleted successfully.' }
      format.json { head :no_content }
    end
  end

  private

  def set_customer
    @customer = current_tenant.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :first_name, :last_name, :email, :phone, :address,
      :city, :state, :zip_code, :notes, :profile_image
    )
  end


  def filter_customer_access(customers)
    return customers if current_user.can_access_all_studios?(current_tenant)

    # Staff can only see customers who have appointments at their studio
    accessible_studio_ids = current_user.accessible_studio_locations(current_tenant).pluck(:id)
    customers.joins(:appointments)
             .where(appointments: { studio_location_id: accessible_studio_ids })
             .distinct
  end

end
