class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :subscriber, polymorphic: true, null: false
      t.string :stripe_subscription_id, null: false
      t.integer :plan_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, default: 'usd'
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, [:subscriber_type, :subscriber_id]
    add_index :subscriptions, [:status, :current_period_end]
  end
end
