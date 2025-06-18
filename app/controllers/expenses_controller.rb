# app/controllers/expenses_controller.rb - FIXED VERSION (Array Issue Resolved)
class ExpensesController < ApplicationController
  before_action :authenticate_user!
  include TenantScoped
  include StudioFiltering # Add this module for studio filtering
  before_action :set_expense, only: [:show, :edit, :update, :destroy, :approve, :reject]

  # Add CanCan authorization
  load_and_authorize_resource :expense, through: :current_tenant
  skip_load_resource only: [:index, :new, :create]

  def index
    # CanCan will authorize :index action automatically
    authorize! :index, Expense

    # FIXED: Start with tenant expenses and apply CanCan filtering
    @expenses = current_tenant.expenses.includes(:studio_location, :expense_category, :staff_member)
    @expenses = @expenses.accessible_by(current_ability)

    # FIXED: Apply studio location filtering for customer service and other restricted roles
    @expenses = filter_expenses_by_studio_access(@expenses)

    @expenses = @expenses.recent.page(params[:page]).per(20) rescue @expenses.limit(20)

    # FIXED: Apply same filtering to totals and counts
    accessible_expenses = current_tenant.expenses.accessible_by(current_ability)
    accessible_expenses = filter_expenses_by_studio_access(accessible_expenses)

    @total_this_month = accessible_expenses
                          .where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month)
                          .sum(:amount) rescue 0
    @total_this_year = accessible_expenses
                         .where(expense_date: Date.current.beginning_of_year..Date.current.end_of_year)
                         .sum(:amount) rescue 0
    @pending_approval_count = accessible_expenses
                                .where(approval_status: 'pending_approval').count rescue 0
    @overdue_count = accessible_expenses
                       .where(payment_status: 'pending')
                       .where('expense_date < ?', Date.current - 30.days).count rescue 0

    # FIXED: Handle both Array and ActiveRecord relation cases for studio locations
    @studio_locations = current_user_accessible_studios_ordered
    @expense_categories = current_tenant.expense_categories.order(:name) rescue []
    @payment_statuses = ['pending', 'paid', 'overdue', 'cancelled', 'refunded']
    @approval_statuses = ['draft', 'pending_approval', 'approved', 'rejected']
  end

  def show
    # Authorization handled by load_and_authorize_resource

    # FIXED: Only show related expenses from accessible studios
    accessible_expenses = current_tenant.expenses.accessible_by(current_ability)
    accessible_expenses = filter_expenses_by_studio_access(accessible_expenses)

    @related_expenses = accessible_expenses
                          .where(expense_category: @expense.expense_category)
                          .where.not(id: @expense.id).limit(5) rescue []
    @current_staff_member = current_staff_member
  end

  def new
    # Create new expense and authorize
    @expense = current_tenant.expenses.build
    authorize! :create, @expense

    @expense.expense_date = Date.current
    @expense.currency = 'USD'
    @expense.payment_status = 'pending'
    @expense.tax_deductible = true
    @expense.staff_member = current_staff_member if current_staff_member

    # FIXED: Set default studio location to user's assigned studio for customer service
    if current_staff_member&.customer_service? && current_staff_member.studio_location.present?
      @expense.studio_location = current_staff_member.studio_location
    end
  end

  def create
    @expense = current_tenant.expenses.build(expense_params)
    @expense.staff_member = current_staff_member if current_staff_member

    # FIXED: For customer service, ensure they can only create expenses for their studio
    if current_staff_member&.customer_service? && current_staff_member.studio_location.present?
      @expense.studio_location = current_staff_member.studio_location
    end

    authorize! :create, @expense

    if @expense.save
      redirect_to expense_path(@expense), notice: 'Expense was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Authorization handled by load_and_authorize_resource
  end

  def update
    # Authorization handled by load_and_authorize_resource

    # FIXED: Prevent customer service from changing studio location
    if current_staff_member&.customer_service? && current_staff_member.studio_location.present?
      expense_params_filtered = expense_params.except(:studio_location_id)
      update_params = expense_params_filtered
    else
      update_params = expense_params
    end

    if @expense.update(update_params)
      redirect_to expense_path(@expense), notice: 'Expense was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Authorization handled by load_and_authorize_resource
    @expense.destroy
    redirect_to expenses_path, notice: 'Expense was successfully deleted.'
  end

  def approve
    # Check specific approval permission
    authorize! :approve, @expense

    @expense.update(
      approval_status: 'approved',
      approved_by: current_staff_member,
      approved_at: Time.current,
      approval_notes: params[:approval_notes]
    )
    redirect_to expense_path(@expense), notice: 'Expense approved successfully.'
  end

  def reject
    # Check specific rejection permission
    authorize! :reject, @expense

    @expense.update(
      approval_status: 'rejected',
      approved_by: current_staff_member,
      approved_at: Time.current,
      approval_notes: params[:rejection_notes]
    )
    redirect_to expense_path(@expense), notice: 'Expense rejected.'
  end

  private

  def set_expense
    # This will be handled by load_and_authorize_resource, but keeping for compatibility
    @expense = current_tenant.expenses.find(params[:id]) unless @expense
  end

  def expense_params
    params.require(:expense).permit(
      :title, :description, :amount, :currency, :expense_date,
      :vendor_name, :vendor_contact, :invoice_number, :receipt_number,
      :payment_method, :payment_reference, :payment_date, :payment_status,
      :recurring, :recurring_frequency, :tax_deductible, :notes,
      :studio_location_id, :expense_category_id,
      receipts: []
    )
  end

  def current_staff_member
    @current_staff_member ||= current_tenant.staff_members.find_by(user: current_user)
  end

  # FIXED: Add method to filter expenses by studio access (uses concern method)
  def filter_expenses_by_studio_access(expenses_relation)
    filter_by_studio_access(expenses_relation, :studio_location_id)
  end
end
