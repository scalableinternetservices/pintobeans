# frozen_string_literal: true

class AutoAssignExpertJob < ApplicationJob
  queue_as :default

  # Automatically assigns a conversation to the most suitable expert in the background
  # This job is triggered when a new conversation is created
  #
  # @param conversation_id [Integer] The ID of the conversation to assign
  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    
    unless conversation
      Rails.logger.warn("AutoAssignExpertJob: Conversation #{conversation_id} not found")
      return
    end

    # Skip if already assigned
    if conversation.assigned_expert_id.present?
      Rails.logger.info("AutoAssignExpertJob: Conversation #{conversation_id} already assigned to expert #{conversation.assigned_expert_id}")
      return
    end

    # Perform auto-assignment
    service = AutoExpertAssignmentService.new(conversation)
    result = service.assign

    # Log the result
    if result[:success]
      Rails.logger.info("AutoAssignExpertJob: Successfully assigned conversation #{conversation_id} to expert #{result[:expert].id}")
    else
      Rails.logger.info("AutoAssignExpertJob: Failed to assign conversation #{conversation_id}: #{result[:reason]}")
    end
  rescue StandardError => e
    # Log error but don't fail the job - the conversation is still valid
    Rails.logger.error("AutoAssignExpertJob error for conversation #{conversation_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end

