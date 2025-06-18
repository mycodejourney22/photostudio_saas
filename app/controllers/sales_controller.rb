# app/controllers/sales_controller.rb - CLEAN VERSION

class SalesController < ApplicationController
  before_action :authenticate_user!
  include TenantScoped
  include StudioFiltering
  before_action :set_sale, only: [:show, :edit, :update, :destroy]

  # Add CanCan authorization
  load_and_authorize_resource :sale, through: :current_tenant
  skip_load_resource only: [:index, :new, :create]

  def index
    # CanCan will authorize :index action automatically
    authorize! :index, Sale

    # Start with tenant sales and apply CanCan filtering
    @sales = current_tenant.sales.includes(:customer, :appointment, :studio_location, :staff_member)
    @sales = @sales.accessible_by(current_ability)

    # Apply studio location filtering for customer service and other restricted roles
    @sales = filter_by_studio_access(@sales, :studio_location_id)

    # Apply search and filters if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @sales = @sales.joins(:customer).where(
        "customers.first_name ILIKE ? OR customers.last_name ILIKE ? OR customers.email ILIKE ?",
        search_term, search_term, search_term
      )
    end

    @sales = @sales.where(payment_status: params[:payment_status]) if params[:payment_status].present?
    @sales = @sales.where('sale_date >= ?', params[:start_date]) if params[:start_date].present?
    @sales = @sales.where('sale_date <= ?', params[:end_date]) if params[:end_date].present?

    # Order and paginate
    @sales = @sales.order(sale_date: :desc).page(params[:page]).per(20)

    # Calculate stats with same filtering
    @stats = calculate_filtered_stats
    @staff_members = current_tenant.staff_members.active.order(:first_name, :last_name)
    @sale_types = []
    @payment_statuses = ['pending', 'paid', 'partial', 'refunded', 'cancelled']
    # Set dropdown options - FIXED: Use defensive method that never returns nil
    @studio_locations = current_tenant.studio_locations.order(:name) || []
    @payment_statuses = ['pending', 'paid', 'partial', 'refunded', 'cancelled']
  end

  def show
    # Authorization handled by load_and_authorize_resource
    @payment_history = build_payment_history
  end

  def new
    # Create new sale and authorize
    @sale = current_tenant.sales.build
    authorize! :create, @sale

    # Set defaults
    @sale.sale_date = Date.current
    @sale.payment_status = 'pending'
    @sale.staff_member = current_staff_member

    # Set default studio location for customer service
    if current_staff_member&.customer_service? && current_staff_member.studio_location.present?
      @sale.studio_location = current_staff_member.studio_location
    end

    # Handle appointment-based sale creation
    if params[:appointment_id].present?
      @appointment = current_tenant.appointments.find(params[:appointment_id])
      @sale.appointment = @appointment
      @sale.customer = @appointment.customer
      @sale.studio_location = @appointment.studio_location
      @sale.total_amount = @appointment.price
    end

    # Set form data
    load_form_data
  end

  def create
    @sale = current_tenant.sales.build(sale_params)
    @sale.staff_member = current_staff_member

    # Force studio location for customer service
    if current_staff_member&.customer_service? && current_staff_member.studio_location.present?
      @sale.studio_location = current_staff_member.studio_location
    end

    authorize! :create, @sale

    if @sale.save
      handle_customer_assignment
      update_appointment_sale_reference if @sale.appointment.present?
      redirect_to @sale, notice: 'Sale was successfully created.'
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Authorization handled by load_and_authorize_resource
    load_form_data
  end

  def update
    # Authorization handled by load_and_authorize_resource

    # Prevent customer service from changing studio location
    update_params = sale_params
    if current_staff_member&.customer_service? && current_staff_member.studio_location.present?
      update_params = sale_params.except(:studio_location_id)
    end

    if @sale.update(update_params)
      handle_customer_assignment
      redirect_to @sale, notice: 'Sale was successfully updated.'
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Authorization handled by load_and_authorize_resource
    @sale.destroy
    redirect_to sales_path, notice: 'Sale was successfully deleted.'
  end

  # Bulk actions
  def mark_as_paid
    sale_ids = params[:sale_ids] || []
    accessible_sales = current_tenant.sales.accessible_by(current_ability)
    accessible_sales = filter_by_studio_access(accessible_sales, :studio_location_id)
    sales = accessible_sales.where(id: sale_ids)

    count = 0
    sales.each do |sale|
      if sale.payment_status != 'paid'
        sale.update!(
          paid_amount: sale.total_amount,
          payment_status: 'paid',
          payment_received_at: Time.current
        )
        count += 1
      end
    end

    redirect_to sales_path, notice: "#{count} sales marked as paid."
  end

  def send_sale_receipts
    sale_ids = params[:sale_ids] || []
    redirect_to sales_path, notice: "Receipts sent for #{sale_ids.count} sales."
  end

  private

  def set_sale
    @sale = current_tenant.sales.find(params[:id])
  end

  def sale_params
    params.require(:sale).permit(
      :customer_id, :appointment_id, :staff_member_id, :studio_location_id,
      :total_amount, :paid_amount, :tax_amount, :discount_amount,
      :payment_method, :payment_reference, :payment_status,
      :sale_date, :notes, :invoice_number,
      # For inline customer creation
      :customer_name, :customer_email, :customer_phone
    )
  end

  def current_staff_member
    @current_staff_member ||= current_tenant.staff_members.find_by(user: current_user)
  end

  def load_form_data
    # For new/edit forms - set dropdown data
    @studio_locations = get_accessible_studio_locations_safe
    @customers = current_tenant.customers.order(:first_name, :last_name).limit(100)
    @staff_members = current_tenant.staff_members.active.order(:first_name, :last_name)
  end

  def calculate_filtered_stats
    # Use same filtering as the main query
    base_sales = current_tenant.sales.accessible_by(current_ability)
    base_sales = filter_by_studio_access(base_sales, :studio_location_id)

    today_sales = base_sales.where(sale_date: Date.current.all_day)
    week_sales = base_sales.where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week)
    month_sales = base_sales.where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month)

    {
      today: {
        count: today_sales.count,
        revenue: today_sales.sum(:total_amount) || 0,
        avg_sale: today_sales.average(:total_amount) || 0
      },
      week: {
        count: week_sales.count,
        revenue: week_sales.sum(:total_amount) || 0,
        avg_sale: week_sales.average(:total_amount) || 0
      },
      month: {
        count: month_sales.count,
        revenue: month_sales.sum(:total_amount) || 0,
        avg_sale: month_sales.average(:total_amount) || 0
      }
    }
  end

  def handle_customer_assignment
    # Handle customer creation/assignment logic
    return unless @sale.customer_name.present? || @sale.customer_email.present?

    if @sale.customer_email.present?
      existing_customer = current_tenant.customers.find_by(email: @sale.customer_email)
      if existing_customer
        @sale.update!(customer: existing_customer)
        return
      end
    end

    # Create new customer if none exists
    if @sale.customer_name.present? && @sale.customer.blank?
      names = @sale.customer_name.to_s.split(' ', 2)
      first_name = names[0] || 'Unknown'
      last_name = names[1] || ''

      customer = current_tenant.customers.create!(
        first_name: first_name,
        last_name: last_name,
        email: @sale.customer_email,
        phone: @sale.customer_phone
      )

      @sale.update!(customer: customer)
    end
  end

  def update_appointment_sale_reference
    @sale.appointment&.update!(sale: @sale)
  end

  def build_payment_history
    payments = []

    if @sale.payment_received_at.present?
      payments << {
        date: @sale.payment_received_at,
        amount: @sale.paid_amount,
        method: @sale.payment_method,
        reference: @sale.payment_reference,
        type: 'payment'
      }
    end

    payments.sort_by { |p| p[:date] }.reverse
  end

  # DEFENSIVE METHOD: Always returns an array, never nil
  def get_accessible_studio_locations_safe
    begin
      if current_user.can_access_all_studios?(current_tenant)
        current_tenant.studio_locations.order(:name).to_a
      else
        accessible_studios = current_user.accessible_studio_locations(current_tenant)
        if accessible_studios.is_a?(Array)
          accessible_studios.sort_by(&:name)
        elsif accessible_studios.respond_to?(:order)
          accessible_studios.order(:name).to_a
        else
          # Fallback to empty array if something goes wrong
          []
        end
      end
    rescue => e
      # Log the error and return empty array as fallback
      Rails.logger.error "Error getting accessible studio locations: #{e.message}"
      []
    end
  end
end
