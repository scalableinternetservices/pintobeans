class Conversation < ApplicationRecord
  belongs_to :initiator, class_name: "User"
  belongs_to :assigned_expert, class_name: "User", optional: true
  has_many :messages, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: %w[waiting active resolved] }

  scope :for_user, ->(user) {
    where("initiator_id = ? OR assigned_expert_id = ?", user.id, user.id)
  }

  scope :waiting, -> { where(status: "waiting") }
  
  scope :assigned_to, ->(expert) { where(assigned_expert_id: expert.id) }

  def unread_count_for(user)
    return 0 unless user
    
    if user == initiator
      messages.where.not(sender_id: user.id).where(is_read: false).count
    elsif user == assigned_expert
      messages.where.not(sender_id: user.id).where(is_read: false).count
    else
      0
    end
  end
end

