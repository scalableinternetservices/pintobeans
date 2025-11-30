# frozen_string_literal: true

class AutoResponseService
  MODEL_ID = "anthropic.claude-3-5-haiku-20241022-v1:0"

  def initialize(conversation, message_content)
    @conversation = conversation
    @message_content = message_content
    @bedrock_client = BedrockClient.new(model_id: MODEL_ID)
  end

  # Generate an automatic response based on the expert's FAQ
  # Returns nil if no appropriate response can be generated
  def generate_response
    return nil unless @conversation.assigned_expert

    expert_profile = @conversation.assigned_expert.expert_profile
    return nil unless expert_profile

    faq = expert_profile.faq
    return nil unless faq.present? && faq.is_a?(Array)

    # Build FAQ context
    faq_context = faq.map.with_index do |item, idx|
      "Q#{idx + 1}: #{item['question']}\nA#{idx + 1}: #{item['answer']}"
    end.join("\n\n")

    system_prompt = <<~SYSTEM
      You are a helpful assistant responding to user questions on behalf of an expert.
      You have access to the expert's FAQ which contains information about common questions.

      FAQ:
      #{faq_context}

      IMPORTANT INSTRUCTIONS:
      1. If the user's question matches or is similar to a question in the FAQ, use that information to generate a helpful response.
      2. REPHRASE the FAQ answer into a natural, direct response to the user.
      3. Address the user directly (use "you" not "them").
      4. DO NOT copy the FAQ answer verbatim - the FAQ answers may contain notes or instructions, so convert them into proper responses.
      5. If the question cannot be answered from the FAQ, respond with exactly: "NO_ANSWER"

      Keep responses concise, friendly, and helpful.
    SYSTEM

    user_prompt = <<~USER
      User question: "#{@message_content}"

      Based on the FAQ above, can you answer this question? If yes, provide a natural, helpful response to the user (not a copy of the FAQ text). If no, respond with "NO_ANSWER".
    USER

    begin
      response = @bedrock_client.call(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        max_tokens: 500,
        temperature: 0.3
      )

      output = response[:output_text].strip

      # If the LLM couldn't answer from FAQ, return nil
      return nil if output == "NO_ANSWER" || output.include?("NO_ANSWER")

      output
    rescue => e
      Rails.logger.error("Auto-response LLM call failed: #{e.message}")
      nil
    end
  end
end

