# app/controllers/sales_controller.rb (Enhanced version)
class SalesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sale, only: [:show, :edit, :update, :destroy, :add_payment]
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
        total_price: @appointment.price,
        duration_minutes: @appointment.duration_minutes,
        service_tier: @appointment.service_tier
      )
    else
      # Start with one empty sale item for non-appointment sales
      @sale.sale_items.build
    end
  end

  # def create
  #   @sale = current_tenant.sales.build(sale_params)

  #   # Handle different save types
  #   if params[:commit] == 'draft'
  #     @sale.sale_status = 'pending'
  #     @sale.payment_status = 'unpaid'
  #     @sale.paid_amount = 0  # Force draft to be unpaid
  #   end

  #   # Ensure sale items have proper tenant assignment
  #   @sale.sale_items.each do |item|
  #     item.tenant = current_tenant
  #   end

  #   if @sale.save
  #     # Create customer record if needed and not from appointment
  #     create_or_update_customer_record if should_create_customer?

  #     # Update appointment if this sale is linked to one
  #     update_appointment_sale_reference if @sale.appointment_id.present?

  #     redirect_to @sale, notice: 'Sale created successfully.'
  #   else
  #     load_form_data
  #     render :new, status: :unprocessable_entity
  #   end
  # end

def create
  @sale = current_tenant.sales.build(sale_params)

  # CRITICAL FIX: Set flag to indicate user provided payment information
  if sale_params[:paid_amount].present?
    @sale.user_provided_payment = true
  end

  # Only set staff member automatically if none was provided in the form
  unless @sale.staff_member_id.present?
    @sale.staff_member = current_user.staff_members.find_by(tenant: current_tenant) ||
                        current_tenant.staff_members.customer_service.first
  end

  # Set payment status based on what user actually entered
  if sale_params[:paid_amount].present? && sale_params[:paid_amount].to_f > 0
    @sale.payment_status = determine_payment_status(sale_params[:paid_amount].to_f, @sale.total_amount || 0)
    @sale.payment_received_at = Time.current if @sale.payment_status.in?(['paid', 'partial'])
  else
    @sale.payment_status = 'unpaid'
    @sale.paid_amount = 0
  end

  # Set sales status to confirmed when creating a sale
  @sale.sale_status = 'confirmed'

  if @sale.save
    redirect_to @sale, notice: 'Sale created successfully.'
  else
    load_form_data
    render :new, status: :unprocessable_entity
  end
end


  def update
    if @sale.update(sale_params)
      # Update payment status if paid amount changed
      if @sale.saved_change_to_paid_amount?
        @sale.update_columns(
          payment_status: determine_payment_status(@sale.paid_amount, @sale.total_amount || 0),
          payment_received_at: (@sale.paid_amount > 0 ? Time.current : nil)
        )
      end

      redirect_to @sale, notice: 'Sale updated successfully.'
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end



  def edit
  end

  def update
    if @sale.update(sale_params)
      # Update payment status if paid amount changed
      if @sale.saved_change_to_paid_amount?
        @sale.update_columns(
          payment_status: determine_payment_status(@sale.paid_amount, @sale.total_amount || 0),
          payment_received_at: (@sale.paid_amount > 0 ? Time.current : nil)
        )
      end

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

  # AJAX endpoint for adding payment
  def add_payment
    amount = params[:amount].to_f
    payment_method = params[:payment_method]
    reference = params[:reference]

    begin
      @sale.add_payment!(amount, method: payment_method, reference: reference)

      render json: {
        success: true,
        message: "Payment of $#{amount} added successfully",
        new_balance: @sale.remaining_balance,
        payment_status: @sale.payment_status
      }
    rescue => e
      render json: {
        success: false,
        message: e.message
      }, status: :unprocessable_entity
    end
  end

  # Quick sale creation for common items
  def quick_passport
    customer = find_or_create_customer_from_params
    staff_member = current_user.staff_members.find_by(tenant: current_tenant) ||
                  current_tenant.staff_members.customer_service.first

    sale = current_tenant.sales.create_passport_sale!(customer, staff_member, quantity: params[:quantity] || 1)

    redirect_to sale, notice: 'Passport photo sale created successfully.'
  rescue => e
    redirect_to new_sale_path, alert: "Error creating passport sale: #{e.message}"
  end

  # Create sale from appointment (enhanced)
  def create_from_appointment
    @appointment = current_tenant.appointments.find(params[:appointment_id])

    if @appointment.sale.present?
      redirect_to @appointment.sale, notice: 'Sale already exists for this appointment'
      return
    end

    begin
      staff_member = current_user.staff_members.find_by(tenant: current_tenant) ||
                    current_tenant.staff_members.customer_service.first

      @sale = create_sale_from_appointment(@appointment, staff_member)
      redirect_to edit_sale_path(@sale), notice: 'Sale created from appointment. Please review and add any additional items.'
    rescue => e
      redirect_to @appointment, alert: "Error creating sale: #{e.message}"
    end
  end

  # Duplicate an existing sale
  def duplicate
    @original_sale = current_tenant.sales.find(params[:id])
    @sale = @original_sale.duplicate_for_new_customer

    load_form_data
    render :new
  end

  # Bulk actions
  def bulk_update
    case params[:bulk_action]
    when 'mark_paid'
      mark_sales_as_paid
    when 'send_receipts'
      send_sale_receipts
    when 'export_csv'
      export_sales_csv
    else
      redirect_to sales_path, alert: 'Invalid bulk action.'
    end
  end

  private

  def set_sale
    @sale = current_tenant.sales.find(params[:id])
  end

  def load_form_data
    @customers = current_tenant.customers.active.order(:first_name, :last_name)
    @staff_members = current_tenant.staff_members.active.order(:first_name, :last_name)
    @service_tiers = current_tenant.service_tiers.active.includes(:service_package)
    # Fix: Find appointments that don't have a sale yet
    @appointments = current_tenant.appointments
                                 .left_joins(:sale)
                                 .where(sales: { id: nil })
                                 .includes(:customer)
                                 .order(:scheduled_at)
  end

  # def sale_params
  #   params.require(:sale).permit(
  #     :customer_id, :appointment_id, :staff_member_id, :customer_name, :customer_email, :customer_phone,
  #     :sale_type, :sale_date, :payment_method, :payment_status, :payment_reference, :paid_amount,
  #     :notes, :special_instructions,
  #     sale_items_attributes: [
  #       :id, :item_type, :name, :description, :quantity, :unit_price, :total_price,
  #       :product_category, :service_tier_id, :sku, :duration_minutes, :discount_amount, :_destroy
  #     ]
  #   )
  # end

  def sale_params
    params.require(:sale).permit(
      :staff_member_id, :appointment_id, :customer_name, :customer_email, :customer_phone,
      :sale_type, :sale_date, :payment_method, :paid_amount, :notes, :special_instructions,
      sale_items_attributes: [
        :id, :item_type, :name, :description, :quantity, :unit_price, :total_price,
        :product_category, :service_tier_id, :sku, :duration_minutes, :_destroy
      ]
    )
  end

  def determine_payment_status(paid_amount, total_amount)
    paid_amount = paid_amount.to_f
    total_amount = total_amount.to_f

    return 'unpaid' if paid_amount <= 0
    return 'paid' if paid_amount >= total_amount
    'partial'
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
      total_price: @appointment.price,
      duration_minutes: @appointment.duration_minutes,
      service_tier: @appointment.service_tier
    )
  end

  def create_sale_from_appointment(appointment, staff_member)
    sale = current_tenant.sales.build(
      appointment: appointment,
      customer: appointment.customer,
      staff_member: staff_member,
      customer_name: appointment.customer.full_name,
      customer_email: appointment.customer.email,
      customer_phone: appointment.customer.phone,
      sale_type: 'appointment',
      sale_date: Time.current,
      sale_status: 'pending'
    )

    # Add the appointment service
    sale.sale_items.build(
      item_type: 'service',
      name: appointment.service_package_name,
      description: "#{appointment.session_type.humanize} session",
      quantity: 1,
      unit_price: appointment.price,
      total_price: appointment.price,
      duration_minutes: appointment.duration_minutes,
      service_tier: appointment.service_tier
    )

    sale.save!

    # Link the appointment to this sale
    appointment.update!(sale: sale)

    sale
  end

  def should_create_customer?
    @sale.customer_id.blank? && @sale.customer_name.present? && @sale.customer_email.present?
  end

  def create_or_update_customer_record
    return unless @sale.customer_name.present?

    # Try to find existing customer by email
    existing_customer = current_tenant.customers.find_by(email: @sale.customer_email) if @sale.customer_email.present?

    if existing_customer
      # Update existing customer
      @sale.update!(customer: existing_customer)
    else
      # Create new customer
      names = @sale.customer_name.split(' ', 2)
      first_name = names[0]
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
    appointment = @sale.appointment
    appointment.update!(sale: @sale) if appointment.present?
  end

  def find_or_create_customer_from_params
    if params[:customer_email].present?
      customer = current_tenant.customers.find_by(email: params[:customer_email])
      return customer if customer
    end

    # Create new customer
    names = params[:customer_name].split(' ', 2)
    current_tenant.customers.create!(
      first_name: names[0] || 'Unknown',
      last_name: names[1] || '',
      email: params[:customer_email],
      phone: params[:customer_phone]
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
        avg_sale: today_sales.average(:total_amount) || 0
      },
      week: {
        count: week_sales.count,
        revenue: week_sales.sum(:total_amount),
        avg_sale: week_sales.average(:total_amount) || 0
      },
      month: {
        count: month_sales.count,
        revenue: month_sales.sum(:total_amount),
        avg_sale: month_sales.average(:total_amount) || 0
      }
    }
  end

  def build_payment_history
    # Build a timeline of payment events
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

    # Add any refunds or adjustments here
    # This could be expanded to track multiple payments

    payments.sort_by { |p| p[:date] }.reverse
  end

  def mark_sales_as_paid
    sale_ids = params[:sale_ids] || []
    sales = current_tenant.sales.where(id: sale_ids)

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
    # Implementation for sending receipts via email
    redirect_to sales_path, notice: "Receipts sent for #{sale_ids.count} sales."
  end

  def find_staff_member_for_sale
    # First try to find current user's staff member record
    current_user_staff = current_user.staff_members.find_by(tenant: current_tenant)

    if current_user_staff&.can_process_sales?
      return current_user_staff
    end

    # Otherwise find any staff member who can process sales
    current_tenant.staff_members.can_process_sales.active.first ||
    current_tenant.staff_members.customer_service.active.first ||
    current_tenant.staff_members.managers.active.first ||
    current_tenant.staff_members.where(role: 'owner').active.first
  end
end
