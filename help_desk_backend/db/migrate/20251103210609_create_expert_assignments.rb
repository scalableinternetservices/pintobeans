class CreateExpertAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_assignments do |t|

      # foreign keys: conversation_id maps to a Conversation's id, expert_id maps to ExpertProfile's id
      t.references :conversation, null: false, foreign_key: true
      t.references :expert, null: false, foreign_key: { to_table: :expert_profiles }
      
      # other fields
      t.string :status, null: false
      t.datetime :assigned_at, null: false
      t.datetime :resolved_at
      t.timestamps
    end
  end
end
