class TenantUser < ApplicationRecord
  belongs_to :tenant
  belongs_to :user

  validates :role, inclusion: { in: %w[owner admin staff] }
  validates :user_id, uniqueness: { scope: :tenant_id }

  enum role: { owner: 0, admin: 1, staff: 2 }

  scope :active, -> { joins(:user).where(users: { active: true }) }
end
