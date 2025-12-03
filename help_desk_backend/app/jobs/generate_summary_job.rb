class GenerateSummaryJob < ApplicationJob
  queue_as :default

  # Set to true for synchronous execution (blocks request but works without background workers)
  # Set to false for async execution (requires solid_queue worker running)
  SYNCHRONOUS_MODE = true

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    # Only generate if there are messages and no summary yet
    return if conversation.messages.count == 0
    return if conversation.summary.present?

    summary_service = ConversationSummaryService.new(conversation)
    summary_service.update_summary
  rescue => e
    Rails.logger.error("Failed to generate summary for conversation #{conversation_id}: #{e.message}")
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

