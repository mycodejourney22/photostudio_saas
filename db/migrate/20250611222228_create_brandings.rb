class CreateBrandings < ActiveRecord::Migration[7.1]
  def change
    create_table :brandings do |t|

      t.timestamps
    end
  end
end
