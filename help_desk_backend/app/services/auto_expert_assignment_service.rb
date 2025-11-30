# frozen_string_literal: true

class AutoExpertAssignmentService
  # Automatically assigns a conversation to the most suitable expert
  # Uses LLM to analyze conversation content and expert profiles to find the best match
  
  def initialize(conversation)
    @conversation = conversation
    @bedrock_client = BedrockClient.new(
      model_id: ENV["BEDROCK_MODEL_ID"] || "anthropic.claude-3-5-haiku-20241022-v1:0",
      region: ENV["AWS_REGION"] || "us-west-2"
    )
  end

  # Performs automatic assignment
  # Returns:
  #   - If successful: { success: true, expert: expert_profile }
  #   - If no suitable expert: { success: false, reason: "no_suitable_expert" }
  #   - If error occurs: { success: false, reason: "error", error: error_message }
  def assign
    begin
      # 1. Get all available experts
      experts = ExpertProfile.includes(:user).all
      
      return { success: false, reason: "no_experts_available" } if experts.empty?

      # 2. Build prompts
      system_prompt = build_system_prompt
      user_prompt = build_user_prompt(experts)

      # 3. Call LLM
      response = @bedrock_client.call(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        max_tokens: 500,
        temperature: 0.3  # Lower temperature for more consistent results
      )

      # 3.5. Log LLM conversation for debugging
      # log_llm_conversation(system_prompt, user_prompt, response)

      # 4. Parse LLM response
      expert_id = parse_llm_response(response[:output_text])

      # 5. If LLM returns "NONE", no suitable expert found
      if expert_id.nil? || expert_id.downcase == "none"
        return { success: false, reason: "no_suitable_expert" }
      end

      # 6. Find expert and create assignment
      expert = experts.find { |e| e.id.to_s == expert_id.to_s }
      
      if expert.nil?
        return { success: false, reason: "invalid_expert_id", expert_id: expert_id }
      end

      # 7. Create ExpertAssignment record
      assignment = ExpertAssignment.create!(
        conversation: @conversation,
        expert_profile: expert,
        assigned_at: Time.current,
        status: "Active"
      )

      # 8. Update Conversation's assigned_expert_id and status
      @conversation.update!(
        assigned_expert_id: expert.user_id,
        status: "active"
      )

      { success: true, expert: expert, assignment: assignment }

    rescue => e
      Rails.logger.error("AutoExpertAssignmentService error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { success: false, reason: "error", error: e.message }
    end
  end

  private

  def build_system_prompt
    <<~PROMPT
      You are an intelligent conversation assignment assistant. Your task is to select the most suitable expert from the available expert list based on the user's question/conversation content.

      Analysis criteria:
      1. Whether the expert's field of expertise (bio) is relevant to the conversation topic
      2. Whether the expert's knowledge base links cover related topics
      3. Select the best matching expert

      Response format requirements:
      - If a suitable expert is found, return only the expert's ID (number)
      - If no suitable expert is found, return only "NONE"
      - Do not return any other explanatory text, only return the ID or "NONE"

      Examples:
      - If expert 3 is most suitable: return "3"
      - If no suitable expert: return "NONE"
    PROMPT
  end

  def build_user_prompt(experts)
    # Build conversation information
    conversation_info = <<~INFO
      Conversation Title: #{@conversation.title}
      Conversation Status: #{@conversation.status}
      Created At: #{@conversation.created_at}
    INFO

    # Add conversation message content
    messages = @conversation.messages.order(created_at: :asc).limit(10)
    if messages.any?
      conversation_info += "\nConversation Messages:\n"
      messages.each do |msg|
        conversation_info += "- [#{msg.sender_role}]: #{msg.content}\n"
      end
    end

    # Build expert list information
    experts_info = "Available Experts:\n\n"
    experts.each do |expert|
      experts_info += <<~EXPERT
        Expert ID: #{expert.id}
        Username: #{expert.user.username}
        Bio: #{expert.bio || 'None'}
        Knowledge Base Links: #{format_knowledge_base_links(expert.knowledge_base_links)}
        
      EXPERT
    end

    # Combine into complete user prompt
    <<~PROMPT
      #{conversation_info}

      #{experts_info}

      Please analyze the above conversation content and expert information to select the most suitable expert.
      Remember: Only return the expert ID or "NONE", no other text.
    PROMPT
  end

  def format_knowledge_base_links(links)
    return "None" if links.nil? || links.empty?
    
    if links.is_a?(Array)
      links.join(", ")
    elsif links.is_a?(Hash)
      links.values.join(", ")
    else
      links.to_s
    end
  end

  def parse_llm_response(response_text)
    # Extract numeric ID or "NONE" from response
    cleaned_response = response_text.strip.upcase
    
    # If it's "NONE", return nil
    return nil if cleaned_response == "NONE"
    
    # Try to extract numeric ID
    match = response_text.match(/\d+/)
    match ? match[0] : nil
  end

  def log_llm_conversation(system_prompt, user_prompt, response)
    # Create log directory if it doesn't exist
    log_dir = Rails.root.join('log', 'llm_conversations')
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)

    # Create log file with timestamp and conversation ID
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "conversation_#{@conversation.id}_#{timestamp}.log"
    log_path = log_dir.join(filename)

    # Write log content
    File.open(log_path, 'w') do |f|
      f.puts "="*80
      f.puts "LLM Conversation Log"
      f.puts "Conversation ID: #{@conversation.id}"
      f.puts "Conversation Title: #{@conversation.title}"
      f.puts "Timestamp: #{Time.now.iso8601}"
      f.puts "="*80
      f.puts
      
      f.puts "-"*80
      f.puts "SYSTEM PROMPT:"
      f.puts "-"*80
      f.puts system_prompt
      f.puts
      
      f.puts "-"*80
      f.puts "USER PROMPT:"
      f.puts "-"*80
      f.puts user_prompt
      f.puts
      
      f.puts "-"*80
      f.puts "LLM RESPONSE:"
      f.puts "-"*80
      f.puts "Output Text: #{response[:output_text]}"
      f.puts "Input Tokens: #{response[:input_tokens]}"
      f.puts "Output Tokens: #{response[:output_tokens]}"
      f.puts
      
      f.puts "="*80
      f.puts "End of Log"
      f.puts "="*80
    end

    Rails.logger.info("LLM conversation logged to: #{log_path}")
  rescue => e
    Rails.logger.error("Failed to log LLM conversation: #{e.message}")
  end
end

