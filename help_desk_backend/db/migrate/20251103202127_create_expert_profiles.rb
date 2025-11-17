class CreateExpertProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_profiles do |t|
      t.text :bio
      t.json :knowledge_base_links

      # Foreign key reference to User Model id value
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end

# Note for Katie and Che: uniqueness: true only works in model file, has to be index: {unique: true} in database file