# frozen_string_literal: true

class AutoAssignExpertJob < ApplicationJob
  queue_as :default

  # Set to true for synchronous execution (blocks request but works without background workers)
  # Set to false for async execution (requires solid_queue worker running)
  SYNCHRONOUS_MODE = true

  # Automatically assigns a conversation to the most suitable expert
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

  # Convenience method to handle sync/async execution
  def self.perform_later_or_now(conversation_id)
    if SYNCHRONOUS_MODE
      perform_now(conversation_id)
    else
      perform_later(conversation_id)
    end
  end
end

