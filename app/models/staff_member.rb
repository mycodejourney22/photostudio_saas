# app/models/staff_member.rb (updated with sales capabilities)
class StaffMember < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :user, optional: true # Only for staff who have login access

  # Appointment relationships
  has_many :appointments_as_photographer, class_name: 'Appointment', foreign_key: 'assigned_photographer_id'
  has_many :appointments_as_editor, class_name: 'Appointment', foreign_key: 'assigned_editor_id'

  has_many :recorded_expenses, class_name: 'Expense', foreign_key: 'staff_member_id', dependent: :nullify
  has_many :approved_expenses, class_name: 'Expense', foreign_key: 'approved_by_id', dependent: :nullify

  # Sales relationships
  has_many :sales, foreign_key: 'staff_member_id', dependent: :restrict_with_error

  # Legacy relationships (if you have these models)
  has_many :photoshoot_sessions_as_photographer, class_name: 'PhotoshootSession', foreign_key: 'photographer_id', dependent: :nullify
  has_many :photoshoot_sessions_as_editor, class_name: 'PhotoshootSession', foreign_key: 'editor_id', dependent: :nullify

  validates :first_name, :last_name, presence: true
  validates :role, inclusion: {
    in: %w[customer_service photographer editor receptionist assistant manager owner]
  }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :user_id, uniqueness: { scope: :tenant_id }, allow_nil: true
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  has_many :recorded_expenses, class_name: 'Expense', foreign_key: 'staff_member_id', dependent: :nullify
  has_many :approved_expenses, class_name: 'Expense', foreign_key: 'approved_by_id', dependent: :nullify

  scope :active, -> { where(active: true) }
  scope :with_login, -> { where(has_login: true) }
  scope :without_login, -> { where(has_login: false) }
  scope :by_role, ->(role) { where(role: role) }
  scope :photographers, -> { where(role: 'photographer') }
  scope :editors, -> { where(role: 'editor') }
  scope :customer_service, -> { where(role: 'customer_service') }
  scope :managers, -> { where(role: 'manager') }
  scope :can_process_sales, -> { where(role: ['customer_service', 'manager', 'owner']) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_user_accounts, -> { joins(:user) }
  scope :without_user_accounts, -> { where(user_id: nil) }

  AVAILABLE_ROLES = %w[
    owner
    manager
    customer_service
    photographer
    editor
    receptionist
    assistant
  ].freeze

   validates :role, inclusion: { in: AVAILABLE_ROLES }


  def full_name
    "#{first_name} #{last_name}".strip
  end

  def can_login?
    has_login && user.present?
  end

  def display_role
    role.humanize
  end

  def can_be_deleted?
    !has_active_appointments? && !has_sales_records?
  end

  def has_active_appointments?
    return false unless respond_to?(:appointments_as_photographer) || respond_to?(:appointments_as_editor)

    (appointments_as_photographer&.exists? || false) ||
    (appointments_as_editor&.exists? || false)
  end


  def has_expense_records?
    recorded_expenses.exists? || approved_expenses.exists?
  end

  def can_approve_expenses?
    %w[owner manager].include?(role)
  end

  def can_record_expenses?
    # Most staff members can record expenses, but you can customize this
    active?
  end


  def has_sales_records?
    return false unless respond_to?(:sales)
    sales&.exists? || false
  end

  def build_default_operating_hours
    # This method is for studio_location, but adding here for consistency
  end

  # Role checking methods
  def photographer?
    role == 'photographer'
  end

  def editor?
    role == 'editor'
  end

  def customer_service?
    role == 'customer_service'
  end

  def manager?
    role == 'manager'
  end

  def owner?
    role == 'owner'
  end

  def receptionist?
    role == 'receptionist'
  end

  def assistant?
    role == 'assistant'
  end

  # Permission methods
  def can_process_sales?
    customer_service? || manager? || owner?
  end

  def can_manage_appointments?
    customer_service? || manager? || owner?
  end

  def can_assign_staff?
    manager? || owner?
  end

  def can_view_reports?
    customer_service? || manager? || owner?
  end

  def can_manage_customers?
    customer_service? || manager? || owner?
  end

  def can_edit_studio_settings?
    manager? || owner?
  end

  # Sales performance methods
  def sales_this_month
    sales.where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  def total_sales_amount(period = :all_time)
    case period
    when :today
      sales.where(sale_date: Date.current.all_day).sum(:total_amount)
    when :this_week
      sales.where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week).sum(:total_amount)
    when :this_month
      sales.where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month).sum(:total_amount)
    when :this_year
      sales.where(sale_date: Date.current.beginning_of_year..Date.current.end_of_year).sum(:total_amount)
    else
      sales.sum(:total_amount)
    end
  end

  def total_sales_count(period = :all_time)
    case period
    when :today
      sales.where(sale_date: Date.current.all_day).count
    when :this_week
      sales.where(sale_date: Date.current.beginning_of_week..Date.current.end_of_week).count
    when :this_month
      sales.where(sale_date: Date.current.beginning_of_month..Date.current.end_of_month).count
    when :this_year
      sales.where(sale_date: Date.current.beginning_of_year..Date.current.end_of_year).count
    else
      sales.count
    end
  end

  def average_sale_amount(period = :all_time)
    total = total_sales_amount(period)
    count = total_sales_count(period)
    return 0 if count.zero?

    total / count
  end

  # Appointment assignment methods
  def assigned_appointments_today
    today = Date.current
    photographer_appointments = appointments_as_photographer.where(scheduled_at: today.all_day)
    editor_appointments = appointments_as_editor.where(scheduled_at: today.all_day)

    (photographer_appointments + editor_appointments).uniq.sort_by(&:scheduled_at)
  end

  def upcoming_assignments(days = 7)
    start_date = Date.current
    end_date = days.days.from_now

    photographer_appointments = appointments_as_photographer.where(scheduled_at: start_date..end_date)
    editor_appointments = appointments_as_editor.where(scheduled_at: start_date..end_date)

    (photographer_appointments + editor_appointments).uniq.sort_by(&:scheduled_at)
  end

  def workload_for_date(date)
    photographer_time = appointments_as_photographer.where(scheduled_at: date.all_day).sum(:duration_minutes)
    editor_time = appointments_as_editor.where(scheduled_at: date.all_day).sum(:duration_minutes)

    photographer_time + editor_time
  end

  # Performance metrics
  def performance_stats(period = :this_month)
    case period
    when :today
      date_range = Date.current.all_day
    when :this_week
      date_range = Date.current.beginning_of_week..Date.current.end_of_week
    when :this_month
      date_range = Date.current.beginning_of_month..Date.current.end_of_month
    when :this_year
      date_range = Date.current.beginning_of_year..Date.current.end_of_year
    else
      date_range = nil
    end

    stats = {}

    if can_process_sales?
      if date_range
        period_sales = sales.where(sale_date: date_range)
      else
        period_sales = sales
      end

      stats[:sales] = {
        count: period_sales.count,
        total_amount: period_sales.sum(:total_amount),
        average_amount: period_sales.count > 0 ? period_sales.sum(:total_amount) / period_sales.count : 0
      }
    end

    if photographer?
      if date_range
        photo_appointments = appointments_as_photographer.where(scheduled_at: date_range)
      else
        photo_appointments = appointments_as_photographer
      end

      stats[:photography] = {
        appointments: photo_appointments.count,
        completed: photo_appointments.where(status: 'completed').count,
        total_hours: photo_appointments.sum(:duration_minutes) / 60.0
      }
    end

    if editor?
      if date_range
        edit_appointments = appointments_as_editor.where(scheduled_at: date_range)
      else
        edit_appointments = appointments_as_editor
      end

      stats[:editing] = {
        appointments: edit_appointments.count,
        completed: edit_appointments.where(editing_completed_at: date_range).count,
        total_hours: edit_appointments.sum(:duration_minutes) / 60.0
      }
    end

    stats
  end

  # Commission calculation (if you implement commission system)
  def calculate_commission(period = :this_month)
    return 0 unless commission_rate.present?

    total_sales = total_sales_amount(period)
    (total_sales * (commission_rate / 100.0)).round(2)
  end

  # Availability checking
  def available_at?(datetime, duration_minutes = 60)
    end_time = datetime + duration_minutes.minutes

    # Check for conflicting photographer assignments
    photographer_conflicts = appointments_as_photographer.where(
      "(scheduled_at < ? AND scheduled_at + INTERVAL duration_minutes MINUTE > ?) OR " \
      "(scheduled_at < ? AND scheduled_at + INTERVAL duration_minutes MINUTE > ?)",
      end_time, datetime, datetime, end_time
    ).exists?

    # Check for conflicting editor assignments
    editor_conflicts = appointments_as_editor.where(
      "(scheduled_at < ? AND scheduled_at + INTERVAL duration_minutes MINUTE > ?) OR " \
      "(scheduled_at < ? AND scheduled_at + INTERVAL duration_minutes MINUTE > ?)",
      end_time, datetime, datetime, end_time
    ).exists?

    !photographer_conflicts && !editor_conflicts
  end

  def display_permissions
    permissions = []
    permissions << "Process Sales" if can_process_sales?
    permissions << "Manage Appointments" if can_manage_appointments?
    permissions << "Assign Staff" if can_assign_staff?
    permissions << "View Reports" if can_view_reports?
    permissions << "Manage Customers" if can_manage_customers?
    permissions << "Edit Studio Settings" if can_edit_studio_settings?

    permissions.any? ? permissions.join(", ") : "Basic Access"
  end
end
