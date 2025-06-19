# app/models/appointment.rb (updated with staff assignments)
class Appointment < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :customer
  belongs_to :user # staff member who created the appointment
  belongs_to :studio, optional: true # keeping for backward compatibility
  belongs_to :studio_location, optional: true # new location-based system
  belongs_to :service_tier, optional: true # new package-based system
  belongs_to :booked_by_staff, class_name: 'StaffMember', optional: true

  has_many :email_logs, dependent: :destroy


  # Staff assignments for production workflow
  # Check if we have assigned_photographer_id or photographer_id columns
  if column_names.include?('assigned_photographer_id')
    belongs_to :assigned_photographer, class_name: 'StaffMember', optional: true
  elsif column_names.include?('photographer_id')
    belongs_to :photographer, class_name: 'StaffMember', optional: true
    alias_attribute :assigned_photographer, :photographer
    alias_attribute :assigned_photographer_id, :photographer_id
  end

  if column_names.include?('assigned_editor_id')
    belongs_to :assigned_editor, class_name: 'StaffMember', optional: true
  elsif column_names.include?('editor_id')
    belongs_to :editor, class_name: 'StaffMember', optional: true
    alias_attribute :assigned_editor, :editor
    alias_attribute :assigned_editor_id, :editor_id
  end

  # Sale relationship (optional - appointment may generate a sale)
  has_many :sales, dependent: :nullify

  validates :scheduled_at, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :session_type, inclusion: { in: %w[portrait wedding family event commercial, newborn] }
  validates :status, inclusion: { in: %w[pending confirmed in_progress completed cancelled] }
  validates :payment_status, inclusion: { in: %w[unpaid partial_paid paid refunded] }
  validates :booking_source, inclusion: { in: %w[customer staff walk_in online] }

  has_many :email_logs, dependent: :destroy

  # Email automation callbacks
  after_create :send_confirmation_email, if: :should_send_confirmation?
  after_update :send_status_update_email, if: :status_changed_to_important_state?
  after_update :schedule_feedback_request, if: :just_completed?

  # Validate staff assignments based on roles (only if columns exist)
  validate :photographer_must_be_photographer_role, if: -> { assigned_photographer.present? }
  validate :editor_must_be_editor_role, if: -> { assigned_editor.present? }

  scope :upcoming, -> { where(scheduled_at: Time.current..) }
  scope :today, -> { where(scheduled_at: Date.current.all_day) }
  scope :this_week, -> { where(scheduled_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :current_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }

  # Dynamic scopes based on available columns
  if column_names.include?('assigned_photographer_id') || column_names.include?('photographer_id')
    scope :with_photographer, ->(photographer_id) {
      column = column_names.include?('assigned_photographer_id') ? 'assigned_photographer_id' : 'photographer_id'
      where(column => photographer_id)
    }
    scope :needs_photographer, -> {
      column = column_names.include?('assigned_photographer_id') ? 'assigned_photographer_id' : 'photographer_id'
      where(column => nil)
    }
  end

  if column_names.include?('assigned_editor_id') || column_names.include?('editor_id')
    scope :with_editor, ->(editor_id) {
      column = column_names.include?('assigned_editor_id') ? 'assigned_editor_id' : 'editor_id'
      where(column => editor_id)
    }
    scope :needs_editor, -> {
      column = column_names.include?('assigned_editor_id') ? 'assigned_editor_id' : 'editor_id'
      where(column => nil)
    }
  end

  if column_names.include?('shoot_completed_at')
    scope :shoot_completed, -> { where.not(shoot_completed_at: nil) }
  end

  if column_names.include?('editing_completed_at')
    scope :editing_completed, -> { where.not(editing_completed_at: nil) }
  end

  enum status: { pending: 0, confirmed: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum session_type: { portrait: 0, wedding: 1, family: 2, event: 3, commercial: 4, newborn: 5 }
  enum payment_status: { unpaid: 0, partial_paid: 1, paid: 2, refunded: 3 }
  enum booking_source: { customer: 0, staff: 1, walk_in: 2, online: 3 }

  before_save :calculate_end_time, :sync_service_tier_data
  after_update :send_status_notification, if: :saved_change_to_status?

  def end_time
    scheduled_at + duration_minutes.minutes
  end

  def can_be_cancelled?
    pending? || confirmed?
  end

  def revenue_impact
    completed? ? price : 0
  end

  def service_package
    service_tier&.service_package
  end

  def service_package_name
    service_package&.name || session_type&.humanize
  end

  def service_tier_name
    service_tier&.name || 'Custom'
  end

  def main_sale
    # The first sale created for this appointment is the main sale
    sales.order(:created_at).first
  end

  def additional_sales
    # All sales except the first one are additional sales
    main_sale_id = main_sale&.id
    return Sale.none unless main_sale_id

    sales.where.not(id: main_sale_id).order(:created_at)
  end

  def total_sales_amount
    sales.sum(:total_amount)
  end

  def has_main_sale?
    main_sale.present?
  end

  def has_additional_sales?
    additional_sales.any?
  end

  def sales_summary
    {
      main_sale: main_sale,
      additional_sales: additional_sales,
      total_amount: total_sales_amount,
      count: sales.count
    }
  end

  def location_name
    studio_location&.name || studio&.name || 'TBD'
  end

  def total_amount
    price + (deposit_amount || 0)
  end

  def remaining_balance
    total_amount - (paid_amount || 0)
  end

  def payment_complete?
    paid? || (paid_amount && paid_amount >= total_amount)
  end

  def requires_deposit?
    deposit_amount.present?
  end

  # Production workflow methods
  def photographer_name
    assigned_photographer&.full_name || 'Not assigned'
  end

  def editor_name
    assigned_editor&.full_name || 'Not assigned'
  end

  def shoot_completed?
    respond_to?(:shoot_completed_at) && shoot_completed_at.present?
  end

  def editing_completed?
    respond_to?(:editing_completed_at) && editing_completed_at.present?
  end

  def production_complete?
    shoot_completed? && editing_completed?
  end

  def days_until_delivery
    return nil unless respond_to?(:delivery_date) && delivery_date
    (delivery_date - Date.current).to_i
  end

  def overdue_delivery?
    respond_to?(:delivery_date) && delivery_date && delivery_date < Date.current
  end

  def mark_shoot_completed!(completed_at = Time.current)
    if respond_to?(:shoot_completed_at=)
      update!(shoot_completed_at: completed_at, status: 'in_progress')
    else
      raise "shoot_completed_at column not available"
      update!(status: 'in_progress')

    end
  end

  def mark_editing_completed!(completed_at = Time.current)
    if respond_to?(:editing_completed_at=)
      update!(editing_completed_at: completed_at, status: 'completed')
    else
      raise "editing_completed_at column not available"
      update!(status: 'completed')

    end
  end

  def assign_photographer!(photographer)
    raise "Photographer must belong to the same tenant" unless photographer.tenant_id == tenant_id
    raise "Staff member is not a photographer" unless photographer.photographer?

    if respond_to?(:assigned_photographer_id=)
      update!(assigned_photographer: photographer)
    elsif respond_to?(:photographer_id=)
      update!(photographer: photographer)
    else
      raise "No photographer assignment column available"
    end

    Rails.logger.info "Photographer #{photographer.full_name} assigned to appointment #{id}"
  end

  def assign_editor!(editor)
    raise "Editor must belong to the same tenant" unless editor.tenant_id == tenant_id
    raise "Staff member is not an editor" unless editor.editor?

    if respond_to?(:assigned_editor_id=)
      update!(assigned_editor: editor)
    elsif respond_to?(:editor_id=)
      update!(editor: editor)
    else
      raise "No editor assignment column available"
    end

    Rails.logger.info "Editor #{editor.full_name} assigned to appointment #{id}"
  end

  def unassign_photographer!
    update!(assigned_photographer: nil)
    Rails.logger.info "Photographer unassigned from appointment #{id}"
  end

  def unassign_editor!
    update!(assigned_editor: nil)
    Rails.logger.info "Editor unassigned from appointment #{id}"
  end

  # Check if staff member can be assigned
  def can_assign_photographer?(photographer)
    photographer.present? &&
    photographer.tenant_id == tenant_id &&
    photographer.photographer? &&
    photographer.active?
  end

  def can_assign_editor?(editor)
    editor.present? &&
    editor.tenant_id == tenant_id &&
    editor.editor? &&
    editor.active?
  end

  def assigned_photographer
    if respond_to?(:assigned_photographer_id) && assigned_photographer_id.present?
      super
    elsif respond_to?(:photographer_id) && photographer_id.present?
      photographer
    end
  end

  def assigned_editor
    if respond_to?(:assigned_editor_id) && assigned_editor_id.present?
      super
    elsif respond_to?(:editor_id) && editor_id.present?
      editor
    end
  end

  # Helper methods for the view
  def photographer_name
    assigned_photographer&.full_name
  end

  def editor_name
    assigned_editor&.full_name
  end

  # Generate a sale for this appointment
  def create_sale!(staff_member, additional_items: [])
    return sale if sale.present?

    Sale.create!(
      tenant: tenant,
      appointment: self,
      customer: customer,
      staff_member: staff_member,
      customer_name: customer.full_name,
      customer_email: customer.email,
      customer_phone: customer.phone,
      total_amount: price,
      sale_type: 'appointment',
      sale_date: Time.current,
      sale_status: 'confirmed',
      payment_status: payment_status == 'paid' ? 'paid' : 'unpaid',
      paid_amount: paid_amount || 0,
      notes: "Generated from appointment ##{id}",
      sale_items_attributes: [
        {
          tenant: tenant,
          item_type: 'service',
          name: service_package_name,
          description: "#{session_type.humanize} session - #{duration_minutes} minutes",
          quantity: 1,
          unit_price: price,
          total_price: price,
          duration_minutes: duration_minutes,
          service_tier: service_tier
        }
      ] + additional_items
    )
  end

  def create_main_sale!(staff_member, additional_items: [])
    return main_sale if has_main_sale?

    Sale.create!(
      tenant: tenant,
      appointment: self,
      customer: customer,
      staff_member: staff_member,
      customer_name: customer.full_name,
      customer_email: customer.email,
      customer_phone: customer.phone,
      total_amount: price,
      sale_type: 'appointment',
      sale_date: Time.current,
      sale_status: 'confirmed',
      payment_status: payment_status == 'paid' ? 'paid' : 'unpaid',
      paid_amount: paid_amount || 0,
      notes: "Main sale for appointment ##{id}",
      sale_items_attributes: [
        {
          tenant: tenant,
          item_type: 'service',
          name: service_package_name,
          description: "#{session_type.humanize} session - #{duration_minutes} minutes",
          quantity: 1,
          unit_price: price,
          total_price: price,
          duration_minutes: duration_minutes,
          service_tier: service_tier
        }
      ] + additional_items
    )
  end

  def add_additional_sale!(staff_member, items: [], sale_type: 'walk_in', notes: nil)
    Sale.create!(
      tenant: tenant,
      appointment: self,
      customer: customer,
      staff_member: staff_member,
      customer_name: customer.full_name,
      customer_email: customer.email,
      customer_phone: customer.phone,
      sale_type: sale_type,
      sale_date: Time.current,
      sale_status: 'confirmed',
      payment_status: 'unpaid',
      notes: notes || "Additional sale for appointment ##{id}",
      sale_items_attributes: items.map do |item|
        item.merge(tenant: tenant)
      end
    )
  end

  def add_frame_sale!(staff_member, frame_type:, price:, quantity: 1)
    add_additional_sale!(
      staff_member,
      items: [{
        item_type: 'product',
        name: frame_type,
        description: "Picture frame",
        quantity: quantity,
        unit_price: price,
        total_price: price * quantity,
        product_category: 'frames'
      }],
      notes: "Frame purchase for appointment ##{id}"
    )
  end

  def add_prints_sale!(staff_member, print_type:, price:, quantity:)
    add_additional_sale!(
      staff_member,
      items: [{
        item_type: 'product',
        name: print_type,
        description: "Photo prints",
        quantity: quantity,
        unit_price: price,
        total_price: price * quantity,
        product_category: 'prints'
      }],
      notes: "Additional prints for appointment ##{id}"
    )
  end

  def add_photobook_sale!(staff_member, book_type:, price:, pages: nil)
    add_additional_sale!(
      staff_member,
      items: [{
        item_type: 'product',
        name: book_type,
        description: pages ? "#{pages}-page photobook" : "Photobook",
        quantity: 1,
        unit_price: price,
        total_price: price,
        product_category: 'photobooks'
      }],
      notes: "Photobook purchase for appointment ##{id}"
    )
  end

  def update_payment_status!
    total_expected = total_sales_amount
    total_paid = sales.sum(:paid_amount)

    new_status = if total_paid >= total_expected
                  'paid'
                elsif total_paid > 0
                  'partial_paid'
                else
                  'unpaid'
                end

    update!(payment_status: new_status, paid_amount: total_paid)
  end

  def sale_summary
    {
      main_sale: main_sale,
      additional_sales: additional_sales,
      total_amount: total_sales_amount,
      count: sales.count,
      main_sale_type: main_sale&.sale_type, # HOW the main sale was created
      additional_sale_types: additional_sales.pluck(:sale_type).uniq
    }
  end

  private

  def calculate_end_time
    # This method can be used for calendar integration
  end

  def sync_service_tier_data
    # Sync data from service tier if needed
  end

  def send_status_notification
    # Send notifications when status changes
  end

  def photographer_must_be_photographer_role
    unless assigned_photographer.photographer?
      errors.add(:assigned_photographer, "must be a photographer")
    end
  end

  def editor_must_be_editor_role
    unless assigned_editor.editor?
      errors.add(:assigned_editor, "must be an editor")
    end
  end

  def should_send_confirmation?
  customer.email.present? &&
  tenant.smtp_configured? &&
  tenant.confirmations_enabled? &&
  status.in?(['confirmed', 'pending'])
end

def status_changed_to_important_state?
  saved_change_to_status? &&
  status.in?(['confirmed', 'in_progress', 'completed', 'cancelled']) &&
  customer.email.present? &&
  tenant.smtp_configured?
end

def just_completed?
  saved_change_to_status? &&
  status == 'completed' &&
  tenant.feedback_requests_enabled?
end

def send_confirmation_email
  AppointmentConfirmationJob.perform_later(id)
end

def send_status_update_email
  previous_status = status_before_last_save
  AppointmentMailerService.new(self).send_status_update(previous_status)
end

def schedule_feedback_request
  delay_hours = tenant.feedback_delay_hours || 2
  AppointmentFeedbackJob.set(wait: delay_hours.hours).perform_later(id)
end

# Add this method for checking if just created
def just_created?
  created_at >= 5.minutes.ago
end

# Email token helpers
def generate_cancellation_token
  payload = {
    appointment_id: id,
    customer_email: customer.email,
    action: 'cancel',
    expires_at: 24.hours.from_now.to_i
  }
  JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
end

def generate_reschedule_token
  payload = {
    appointment_id: id,
    customer_email: customer.email,
    action: 'reschedule',
    expires_at: 7.days.from_now.to_i
  }
  JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
end

def gallery_ready?
  # Implement based on your gallery/photo delivery system
  # For now, assume it's ready if appointment is completed and has been 24+ hours
  completed? && completed_at.present? && completed_at <= 24.hours.ago
end
end
