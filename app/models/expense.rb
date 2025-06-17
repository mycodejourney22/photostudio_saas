class Expense < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :studio_location
  belongs_to :expense_category
  belongs_to :staff_member, optional: true
  belongs_to :approved_by, class_name: 'StaffMember', optional: true

  has_many :expense_attachments, dependent: :destroy
  has_many_attached :receipts

  validates :title, presence: true, length: { maximum: 200 }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :expense_date, presence: true
  validates :currency, inclusion: { in: %w[USD EUR GBP CAD AUD] }
  validates :recurring_frequency, inclusion: { in: %w[weekly monthly quarterly yearly] }, allow_blank: true

  # Enums
  enum payment_method: {
    cash: 0,
    check: 1,
    credit_card: 2,
    debit_card: 3,
    bank_transfer: 4,
    online_payment: 5,
    petty_cash: 6,
    company_card: 7
  }

  enum payment_status: {
    pending: 0,
    paid: 1,
    overdue: 2,
    cancelled: 3,
    refunded: 4
  }

  enum approval_status: {
    draft: 0,
    pending_approval: 1,
    approved: 2,
    rejected: 3,
    requires_revision: 4
  }

  # Scopes
  scope :for_location, ->(location) { where(studio_location: location) }
  scope :for_category, ->(category) { where(expense_category: category) }
  scope :for_date_range, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
  scope :this_month, -> { where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :this_year, -> { where(expense_date: Date.current.beginning_of_year..Date.current.end_of_year) }
  scope :recurring_expenses, -> { where(recurring: true) }
  scope :due_for_recurring, -> { where('recurring = ? AND next_due_date <= ?', true, Date.current) }
  scope :recent, -> { order(expense_date: :desc, created_at: :desc) }
  scope :by_amount, ->(direction = :desc) { order(amount: direction) }
  scope :tax_deductible, -> { where(tax_deductible: true) }

  # Callbacks
  before_save :set_next_due_date, if: :recurring_changed_or_frequency_changed?
  after_create :create_recurring_expense, if: :recurring?

  def formatted_amount
    "₦#{amount.to_f}"
  end

  def overdue?
    payment_status == 'pending' && expense_date < Date.current - 30.days
  end

  def can_be_approved_by?(staff_member)
    return false unless staff_member
    %w[owner manager].include?(staff_member.role)
  end

  def approve!(approved_by_staff, notes = nil)
    update!(
      approval_status: :approved,
      approved_by: approved_by_staff,
      approved_at: Time.current,
      approval_notes: notes
    )
  end

  def reject!(rejected_by_staff, notes = nil)
    update!(
      approval_status: :rejected,
      approved_by: rejected_by_staff,
      approved_at: Time.current,
      approval_notes: notes
    )
  end

  def submit_for_approval!
    update!(approval_status: :pending_approval)
  end

  def monthly_recurring?
    recurring? && recurring_frequency == 'monthly'
  end

  def create_next_recurring_expense
    return unless recurring? && next_due_date

    next_expense = self.dup
    next_expense.expense_date = next_due_date
    next_expense.payment_status = :pending
    next_expense.approval_status = :draft
    next_expense.approved_by = nil
    next_expense.approved_at = nil
    next_expense.approval_notes = nil
    next_expense.payment_date = nil
    next_expense.payment_reference = nil

    if next_expense.save
      set_next_due_date
      save!
    end
  end

  private

  def recurring_changed_or_frequency_changed?
    recurring_changed? || recurring_frequency_changed?
  end

  def set_next_due_date
    return unless recurring? && recurring_frequency.present?

    self.next_due_date = case recurring_frequency
                        when 'weekly'
                          expense_date + 1.week
                        when 'monthly'
                          expense_date + 1.month
                        when 'quarterly'
                          expense_date + 3.months
                        when 'yearly'
                          expense_date + 1.year
                        end
  end

  def create_recurring_expense
    # This will be called by a background job in a real application
    # For now, we'll set the next due date
    set_next_due_date if next_due_date.nil?
  end
end
