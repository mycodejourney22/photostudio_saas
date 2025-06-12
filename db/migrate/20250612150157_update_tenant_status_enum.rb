# Create this migration: rails generate migration UpdateTenantStatusEnum
class UpdateTenantStatusEnum < ActiveRecord::Migration[7.1]
  def up
    # First, let's see what statuses we currently have
    execute <<-SQL
      UPDATE tenants
      SET status = 0
      WHERE status IS NULL;
    SQL

    # The enum values will now be:
    # pending: 0, trial: 1, active: 2, suspended: 3, cancelled: 4
    # So existing "trial" (0) becomes "pending" (0)
    # We need to update any existing records appropriately
  end

  def down
    # Revert changes if needed
    execute <<-SQL
      UPDATE tenants
      SET status = 1
      WHERE status = 0;
    SQL
  end
end
