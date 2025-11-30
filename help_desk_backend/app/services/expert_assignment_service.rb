# frozen_string_literal: true

class ExpertAssignmentService
  MODEL_ID = "anthropic.claude-3-5-haiku-20241022-v1:0"

  def initialize(conversation)
    @conversation = conversation
    @bedrock_client = BedrockClient.new(model_id: MODEL_ID)
  end

  # Automatically assign a conversation to the best expert based on the title
  def assign_best_expert
    experts = User.joins(:expert_profile).includes(:expert_profile)

    return nil if experts.empty?

    # If there's only one expert, assign directly
    if experts.count == 1
      return experts.first
    end

    # Build a prompt to ask the LLM to choose the best expert
    expert_descriptions = experts.map.with_index do |expert, idx|
      bio = expert.expert_profile.bio || "No bio provided"
      "Expert #{idx + 1}: #{expert.username} - #{bio}"
    end.join("\n")

    system_prompt = <<~SYSTEM
      You are an expert assignment system. Based on the conversation title and available experts,
      you need to choose the most appropriate expert to handle the conversation.

      Available experts:
      #{expert_descriptions}

      Respond ONLY with the number of the expert (1, 2, 3, etc.) that would be best suited to handle this conversation.
      Do not include any other text in your response.
    SYSTEM

    user_prompt = <<~USER
      Conversation title: "#{@conversation.title}"

      Which expert number should handle this conversation?
    USER

    begin
      response = @bedrock_client.call(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        max_tokens: 10,
        temperature: 0.3
      )

      # Extract the expert number from the response
      expert_number = response[:output_text].strip.to_i

      # Validate the number is within range
      if expert_number >= 1 && expert_number <= experts.count
        experts[expert_number - 1]
      else
        # Fallback: round-robin or least busy expert
        experts.min_by { |e| Conversation.where(assigned_expert_id: e.id, status: "active").count }
      end
    rescue => e
      Rails.logger.error("Expert assignment LLM call failed: #{e.message}")
      # Fallback: assign to expert with least active conversations
      experts.min_by { |e| Conversation.where(assigned_expert_id: e.id, status: "active").count }
    end
  end
end

