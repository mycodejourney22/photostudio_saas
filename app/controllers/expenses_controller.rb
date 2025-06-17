class ExpensesController < ApplicationController
  before_action :authenticate_user!
  include TenantScoped
  before_action :set_expense, only: [:show, :edit, :update, :destroy, :approve, :reject]

  def index
    @expenses = current_tenant.expenses.includes(:studio_location, :expense_category, :staff_member)
    @expenses = @expenses.recent.page(params[:page]).per(20) rescue @expenses.limit(20)

    # Simple totals
    @total_this_month = current_tenant.expenses.where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month).sum(:amount) rescue 0
    @total_this_year = current_tenant.expenses.where(expense_date: Date.current.beginning_of_year..Date.current.end_of_year).sum(:amount) rescue 0
    @pending_approval_count = current_tenant.expenses.where(approval_status: 'pending_approval').count rescue 0
    @overdue_count = current_tenant.expenses.where(payment_status: 'pending').where('expense_date < ?', Date.current - 30.days).count rescue 0

    # Simple filter options
    @studio_locations = current_tenant.studio_locations.order(:name) rescue []
    @expense_categories = current_tenant.expense_categories.order(:name) rescue []
    @payment_statuses = ['pending', 'paid', 'overdue', 'cancelled', 'refunded']
    @approval_statuses = ['draft', 'pending_approval', 'approved', 'rejected']
  end

  def show
    @related_expenses = current_tenant.expenses.where(expense_category: @expense.expense_category).where.not(id: @expense.id).limit(5) rescue []
    @current_staff_member = current_staff_member
  end

  def new
    @expense = current_tenant.expenses.build
    @expense.expense_date = Date.current
    @expense.currency = 'USD'
    @expense.payment_status = 'pending'
    @expense.tax_deductible = true
  end

  def create
    @expense = current_tenant.expenses.build(expense_params)

    if @expense.save
      redirect_to expense_path(@expense), notice: 'Expense was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Nothing needed here
  end

  def update
    if @expense.update(expense_params)
      redirect_to expense_path(@expense), notice: 'Expense was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to expenses_path, notice: 'Expense was successfully deleted.'
  end

  def approve
    if current_staff_member&.can_approve_expenses?
      @expense.update(
        approval_status: 'approved',
        approved_by: current_staff_member,
        approved_at: Time.current,
        approval_notes: params[:approval_notes]
      )
      redirect_to expense_path(@expense), notice: 'Expense approved successfully.'
    else
      redirect_to expense_path(@expense), alert: 'You do not have permission to approve expenses.'
    end
  end

  def reject
    if current_staff_member&.can_approve_expenses?
      @expense.update(
        approval_status: 'rejected',
        approved_by: current_staff_member,
        approved_at: Time.current,
        approval_notes: params[:rejection_notes]
      )
      redirect_to expense_path(@expense), notice: 'Expense rejected.'
    else
      redirect_to expense_path(@expense), alert: 'You do not have permission to reject expenses.'
    end
  end

  private

  def set_expense
    @expense = current_tenant.expenses.find(params[:id])
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
end
