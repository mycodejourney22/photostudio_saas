# app/models/tenant_user.rb
class TenantUser < ApplicationRecord
  belongs_to :tenant
  belongs_to :user
  has_one :staff_member, foreign_key: 'user_id', primary_key: 'user_id'

  validates :role, inclusion: { in: %w[owner admin staff] }
  validates :user_id, uniqueness: { scope: :tenant_id }

  enum role: { owner: 0, admin: 1, staff: 2 }

  scope :active, -> { joins(:user).where(users: { active: true }) }
  scope :can_manage_studio, -> { where(role: ['owner', 'admin']) }
  scope :with_staff_access, -> { where(role: ['owner', 'admin', 'staff']) }

  def can_book_appointments?
    # Owner and admin can always book
    return true if owner? || admin?

    # Staff can book if they're customer service
    staff? && staff_member&.customer_service?
  end

  def staff_role
    staff_member&.role
  end
end
