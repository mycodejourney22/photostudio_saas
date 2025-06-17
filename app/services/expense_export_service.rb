require 'csv'

class ExpenseExportService
  def initialize(expenses)
    @expenses = expenses.includes(:expense_category, :studio_location, :staff_member)
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << csv_headers

      @expenses.find_each do |expense|
        csv << [
          expense.expense_date,
          expense.title,
          expense.description,
          expense.amount,
          expense.currency,
          expense.expense_category.name,
          expense.studio_location.name,
          expense.vendor_name,
          expense.invoice_number,
          expense.receipt_number,
          expense.payment_method.humanize,
          expense.payment_status.humanize,
          expense.approval_status.humanize,
          expense.staff_member&.full_name,
          expense.approved_by&.full_name,
          expense.recurring? ? 'Yes' : 'No',
          expense.recurring_frequency,
          expense.tax_deductible? ? 'Yes' : 'No',
          expense.notes,
          expense.created_at,
          expense.updated_at
        ]
      end
    end
  end

  private

  def csv_headers
    [
      'Date',
      'Title',
      'Description',
      'Amount',
      'Currency',
      'Category',
      'Location',
      'Vendor',
      'Invoice Number',
      'Receipt Number',
      'Payment Method',
      'Payment Status',
      'Approval Status',
      'Recorded By',
      'Approved By',
      'Recurring',
      'Frequency',
      'Tax Deductible',
      'Notes',
      'Created At',
      'Updated At'
    ]
  end
end
