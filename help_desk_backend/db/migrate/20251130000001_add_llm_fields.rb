class AddLlmFields < ActiveRecord::Migration[8.1]
  def change
    # Add summary field to conversations
    add_column :conversations, :summary, :text

    # Add FAQ field to expert_profiles
    add_column :expert_profiles, :faq, :json
  end
end

