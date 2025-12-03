# frozen_string_literal: true

class ConversationSummaryService
  MODEL_ID = "anthropic.claude-3-5-haiku-20241022-v1:0"

  def initialize(conversation)
    @conversation = conversation
    @bedrock_client = BedrockClient.new(model_id: MODEL_ID)
  end

  # Generate a summary of the conversation
  def generate_summary
    messages = @conversation.messages.order(created_at: :asc).limit(20)

    return nil if messages.empty?

    # Build conversation history
    conversation_text = messages.map do |msg|
      role = msg.sender_role == "initiator" ? "User" : "Expert"
      "#{role}: #{msg.content}"
    end.join("\n")

    system_prompt = <<~SYSTEM
      You are a conversation summarizer. Your task is to create a brief, concise summary of a help desk conversation.
      The summary should be no more than 2-3 sentences and capture the main topic and any resolution.
      Keep it professional and informative.
    SYSTEM

    user_prompt = <<~USER
      Please summarize this conversation:

      #{conversation_text}

      Provide a brief 2-3 sentence summary.
    USER

    begin
      response = @bedrock_client.call(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        max_tokens: 200,
        temperature: 0.5
      )

      response[:output_text].strip
    rescue => e
      Rails.logger.error("Conversation summary LLM call failed: #{e.message}")
      # Fallback: use the first message as summary
      messages.first&.content&.truncate(100) || "No summary available"
    end
  end

  # Update the conversation's summary field
  def update_summary
    summary = generate_summary
    @conversation.update(summary: summary) if summary
    summary
  end
end

