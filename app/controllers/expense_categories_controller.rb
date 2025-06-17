# app/controllers/expense_categories_controller.rb
class ExpenseCategoriesController < ApplicationController
  before_action :authenticate_user!
  include TenantScoped
  before_action :require_manager_role
  before_action :set_expense_category, only: [:show, :edit, :update, :destroy, :toggle_status]

  def index
    @expense_categories = current_tenant.expense_categories.ordered
    @expense_categories = @expense_categories.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    # Calculate totals for each category
    @category_totals = {}
    @expense_categories.each do |category|
      @category_totals[category.id] = {
        this_month: category.total_expenses_this_month,
        this_year: category.total_expenses_this_year,
        total_expenses: category.expenses.count
      }
    end
  end

  def show
    @recent_expenses = @expense_category.expenses.recent.limit(10)
    @monthly_totals = calculate_monthly_totals
  end

  def new
    @expense_category = current_tenant.expense_categories.build
    @expense_category.active = true
    @expense_category.sort_order = current_tenant.expense_categories.maximum(:sort_order).to_i + 1
  end

  def create
    @expense_category = current_tenant.expense_categories.build(expense_category_params)

    if @expense_category.save
      redirect_to expense_categories_path, notice: 'Expense category was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense_category.update(expense_category_params)
      redirect_to expense_category_path(@expense_category), notice: 'Expense category was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @expense_category.can_be_deleted?
      @expense_category.destroy
      redirect_to expense_categories_path, notice: 'Expense category was successfully deleted.'
    else
      redirect_to expense_categories_path, alert: 'Cannot delete category with existing expenses.'
    end
  end

  def toggle_status
    @expense_category.update(active: !@expense_category.active?)
    status = @expense_category.active? ? 'activated' : 'deactivated'
    redirect_to expense_categories_path, notice: "Category #{status} successfully."
  end

  private

  def set_expense_category
    @expense_category = current_tenant.expense_categories.find(params[:id])
  end

  def expense_category_params
    params.require(:expense_category).permit(:name, :description, :color, :sort_order, :active)
  end

  def require_manager_role
    current_staff_member = current_tenant.staff_members.find_by(user: current_user)
    unless current_staff_member&.role.in?(%w[owner manager])
      redirect_to expenses_path, alert: 'You do not have permission to manage expense categories.'
    end
  end

  def calculate_monthly_totals
    # Calculate last 6 months of expense totals for this category
    6.times.map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      total = @expense_category.expenses.where(expense_date: month_start..month_end).sum(:amount)
      {
        month: month_start.strftime('%b %Y'),
        total: total
      }
    end.reverse
  end
end
