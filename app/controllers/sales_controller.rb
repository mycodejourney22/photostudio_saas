# app/controllers/sales_controller.rb
class SalesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sale, only: [:show, :edit, :update, :destroy, :add_payment, :add_item, :remove_item]
  before_action :load_form_data, only: [:new, :edit, :create, :update]

  def index
    @sales = current_tenant.sales
                          .includes(:customer, :staff_member, :appointment, :sale_items)
                          .order(sale_date: :desc)

    # Filters
    @sales = @sales.where(sale_type: params[:sale_type]) if params[:sale_type].present?
    @sales = @sales.where(payment_status: params[:payment_status]) if params[:payment_status].present?
    @sales = @sales.where(staff_member_id: params[:staff_id]) if params[:staff_id].present?
    @sales = @sales.where('sale_date >= ?', Date.parse(params[:start_date])) if params[:start_date].present?
    @sales = @sales.where('sale_date <= ?', Date.parse(params[:end_date])) if params[:end_date].present?

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @sales = @sales.where(
        "sale_number ILIKE ? OR customer_name ILIKE ? OR customer_email ILIKE ?",
        search_term, search_term, search_term
      )
    end

    # Pagination
    @sales = @sales.page(params[:page]).per(20)

    # Stats for dashboard cards
    @stats = calculate_sales_stats

    # For filter dropdowns
    @staff_members = current_tenant.staff_members.active.order(:first_name, :last_name)
    @sale_types = Sale.sale_types.keys
    @payment_statuses = Sale.payment_statuses.keys
  end

  def show
    @sale_items = @sale.sale_items.includes(:service_tier)
    @payment_history = build_payment_history
  end

  def new
    @sale = current_tenant.sales.build
    @sale.sale_date = Time.current
    @sale.sale_type = params[:sale_type] || 'walk_in'

    # Pre-fill from appointment if specified
    if params[:appointment_id].present?
      @appointment = current_tenant.appointments.find(params[:appointment_id])
      prefill_from_appointment
    end

    # Start with one empty sale item
    @sale.sale_items.build
  end

  def create
    @sale = current_tenant.sales.build(sale_params)
    @sale.staff_member = current_user.staff_members.find_by(tenant: current_tenant) ||
                        current_tenant.staff_members.customer_service.first

    if @sale.save
      redirect_to @sale, notice: 'Sale created successfully.'
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sale.update(sale_params)
      redirect_to @sale, notice: 'Sale updated successfully.'
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @sale.can_be_deleted?
      @sale.destroy
      redirect_to sales_path, notice: 'Sale deleted successfully.'
    else
      redirect_to @sale, alert: 'Cannot delete this sale.'
    end
  end

  # AJAX endpoints

  # Add payment to sale
  def add_payment
    amount = params[:amount].to_f
    method = params[:payment_method]
    reference = params[:reference]

    begin
      @sale.add_payment!(amount, method: method, reference: reference)

      render json: {
        success: true,
        message: "Payment of $#{amount} added successfully",
        remaining_balance: @sale.remaining_balance,
        payment_status: @sale.payment_status,
        payment_complete: @sale.payment_complete?
      }
    rescue => e
      render json: { success: false, message: e.message }, status: :unprocessable_entity
    end
  end

  # Add item to sale (AJAX)
  def add_item
    item_params = params.require(:sale_item).permit(
      :item_type, :name, :description, :quantity, :unit_price,
      :product_category, :service_tier_id, :sku
    )

    begin
      @sale_item = @sale.sale_items.create!(item_params.merge(tenant: current_tenant))
      @sale.reload # Refresh totals

      render json: {
        success: true,
        message: "#{@sale_item.name} added to sale",
        item_html: render_to_string(partial: 'sales/sale_item_row', locals: { item: @sale_item }),
        total_amount: @sale.total_amount,
        remaining_balance: @sale.remaining_balance
      }
    rescue => e
      render json: { success: false, message: e.message }, status: :unprocessable_entity
    end
  end

  # Remove item from sale (AJAX)
  def remove_item
    @sale_item = @sale.sale_items.find(params[:item_id])
    @sale_item.destroy
    @sale.reload # Refresh totals

    render json: {
      success: true,
      message: "#{@sale_item.name} removed from sale",
      total_amount: @sale.total_amount,
      remaining_balance: @sale.remaining_balance
    }
  rescue => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  # Quick sale presets
  def passport_photos
    customer = current_tenant.customers.find(params[:customer_id])
    staff_member = current_user.staff_members.find_by(tenant: current_tenant)

    sale = Sale.add_passport_sale!(customer, staff_member, quantity: params[:quantity] || 1)

    redirect_to sale, notice: 'Passport photo sale created successfully.'
  rescue => e
    redirect_to new_sale_path, alert: "Error creating passport sale: #{e.message}"
  end

  private

  def set_sale
    @sale = current_tenant.sales.find(params[:id])
  end

  def load_form_data
    @customers = current_tenant.customers.active.order(:first_name, :last_name)
    @staff_members = current_tenant.staff_members.active.order(:first_name, :last_name)
    @service_tiers = current_tenant.service_tiers.active.includes(:service_package)
    @appointments = current_tenant.appointments.where(sale_id: nil).order(:scheduled_at)
  end

  def sale_params
    params.require(:sale).permit(
      :customer_id, :appointment_id, :customer_name, :customer_email, :customer_phone,
      :sale_type, :sale_date, :payment_method, :notes, :special_instructions,
      sale_items_attributes: [
        :id, :item_type, :name, :description, :quantity, :unit_price, :total_price,
        :product_category, :service_tier_id, :sku, :duration_minutes, :_destroy
      ]
    )
  end

  def prefill_from_appointment
    @sale.appointment = @appointment
    @sale.customer = @appointment.customer
    @sale.customer_name = @appointment.customer.full_name
    @sale.customer_email = @appointment.customer.email
    @sale.customer_phone = @appointment.customer.phone
    @sale.sale_type = 'appointment'

    # Add appointment service as first item
    @sale.sale_items.build(
      item_type: 'service',
      name: @appointment.service_package_name,
      description: "#{@appointment.session_type.humanize} session",
      quantity: 1,
      unit_price: @appointment.price,
      duration_minutes: @appointment.duration_minutes,
      service_tier: @appointment.service_tier
    )
  end

  def calculate_sales_stats
    today_sales = current_tenant.sales.where(sale_date: Date.current.all_day)
    week_sales = current_tenant.sales.where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week)
    month_sales = current_tenant.sales.where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month)

    {
      today: {
        count: today_sales.count,
        revenue: today_sales.sum(:total_amount),
        paid: today_sales.paid.sum(:total_amount)
      },
      week: {
        count: week_sales.count,
        revenue: week_sales.sum(:total_amount),
        paid: week_sales.paid.sum(:total_amount)
      },
      month: {
        count: month_sales.count,
        revenue: month_sales.sum(:total_amount),
        paid: month_sales.paid.sum(:total_amount)
      },
      pending_payment: current_tenant.sales.where(payment_status: ['unpaid', 'partial']).sum(:total_amount)
    }
  end

  def build_payment_history
    history = []

    if @sale.payment_received_at
      history << {
        date: @sale.payment_received_at,
        amount: @sale.paid_amount,
        method: @sale.payment_method,
        reference: @sale.payment_reference,
        type: 'payment'
      }
    end

    # You could extend this to track multiple payments if needed
    history
  end
end
