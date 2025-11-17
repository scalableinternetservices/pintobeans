class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  validates :sender_role, presence: true, inclusion: { in: ['initiator', 'expert'] }
  validates :content, presence: true
  validate :is_read_must_be_set
  
  before_validation :set_sender_role, if: -> { sender_role.blank? && sender.present? && conversation.present? }
  after_create :update_conversation_last_message
  
  def set_sender_role
    return if sender_role.present?

    # Only set sender_role if we can determine it from the conversation
    # If sender is neither initiator nor expert, leave it nil so validation fails
    if sender == conversation.initiator
      self.sender_role = "initiator"
    elsif sender == conversation.assigned_expert
      self.sender_role = "expert"
    end
    # If neither, leave it nil - validation will fail
  end
  
  def is_read_must_be_set
    # Check if is_read is nil (not set)
    # The database default doesn't affect the model attribute until save
    if is_read.nil?
      errors.add(:is_read, "can't be blank")
    end
  end
  
  private
  
  def update_conversation_last_message
    conversation.update_column(:last_message_at, created_at)
  end
end