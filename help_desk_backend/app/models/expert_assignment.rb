class ExpertAssignment < ApplicationRecord

  # connect to ExpertProfile and Conversation
  belongs_to :expert_profile, foreign_key: :expert_id
  belongs_to :conversation

  validates :conversation_id, presence: true
  validates :expert_id, presence: true
  validates :assigned_at, presence: true
  validates :status, presence: true

  # sets default status to "Active"
  before_validation :set_default_status, on: :create

  private
  
  def set_default_status
    self.status ||= "Active"
  end

end
