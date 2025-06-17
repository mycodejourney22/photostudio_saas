class RecurringExpenseJob < ApplicationJob
  queue_as :default

  def perform
    # Find all recurring expenses that are due
    due_expenses = Expense.due_for_recurring

    due_expenses.find_each do |expense|
      begin
        expense.create_next_recurring_expense
        Rails.logger.info "Created recurring expense for: #{expense.title}"
      rescue => e
        Rails.logger.error "Failed to create recurring expense for #{expense.title}: #{e.message}"
        # You might want to send notifications to admins here
      end
    end
  end
end
