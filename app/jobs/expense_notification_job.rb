class ExpenseNotificationJob < ApplicationJob
  queue_as :default

  def perform(expense_id, notification_type)
    expense = Expense.find(expense_id)

    case notification_type
    when 'approval_required'
      notify_managers_for_approval(expense)
    when 'approved'
      notify_expense_creator(expense, 'approved')
    when 'rejected'
      notify_expense_creator(expense, 'rejected')
    when 'overdue'
      notify_managers_overdue_expense(expense)
    end
  end

  private

  def notify_managers_for_approval(expense)
    managers = expense.tenant.staff_members.where(role: ['owner', 'manager']).includes(:user)

    managers.each do |manager|
      next unless manager.user&.email

      ExpenseMailer.approval_required(expense, manager).deliver_now
    end
  end

  def notify_expense_creator(expense, status)
    return unless expense.staff_member&.user&.email

    ExpenseMailer.status_updated(expense, status).deliver_now
  end

  def notify_managers_overdue_expense(expense)
    managers = expense.tenant.staff_members.where(role: ['owner', 'manager']).includes(:user)

    managers.each do |manager|
      next unless manager.user&.email

      ExpenseMailer.overdue_expense(expense, manager).deliver_now
    end
  end
end
