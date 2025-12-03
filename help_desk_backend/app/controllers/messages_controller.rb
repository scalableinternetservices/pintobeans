class MessagesController < ApplicationController
  # All actions require JWT authentication via Authenticatable concern
  # JWT token should be provided in Authorization header: "Bearer <token>"
  # The @current_user is set by Authenticatable#authenticate_user! which uses JwtService.decode

  # GET /conversations/:conversation_id/messages
  def index
    conversation = Conversation.find_by(id: params[:conversation_id])

    unless conversation
      return render json: { error: "(a) Conversation not found" }, status: :not_found
    end

    # Check if user has access to this conversation
    unless conversation.initiator == @current_user || conversation.assigned_expert == @current_user
      return render json: { error: "(b) Conversation not found" }, status: :not_found
    end

    messages = conversation.messages
      .includes(:sender)
      .order(created_at: :asc)

    render json: messages.map { |m| message_response(m) }
  end

  # POST /messages
  def create
    conversation = Conversation.find_by(id: params[:conversation_id])

    unless conversation
      return render json: { error: "(1) Conversation not found" }, status: :not_found
    end

    # Check if user has access to this conversation
    unless conversation.initiator == @current_user || conversation.assigned_expert == @current_user
      return render json: { error: "(2) Conversation not found" }, status: :not_found
    end

    # Update conversation status if it was waiting and an expert is assigned
    if conversation.status == "waiting" && conversation.assigned_expert
      conversation.update(status: "active")
    end
    # Determine the sender's role based on the conversation
    current_role = conversation.initiator == @current_user ? "initiator" : "expert"

    message = Message.new(
      conversation: conversation,
      sender: @current_user,
      sender_role: current_role,
      content: params[:content],
      is_read: false
    )

    if message.save
      # If message is from initiator and expert is assigned, try auto-response
      if current_role == "initiator" && conversation.assigned_expert
        auto_response_service = AutoResponseService.new(conversation, message.content)
        auto_response = auto_response_service.generate_response

        if auto_response.present?
          # Create automatic response from expert
          auto_message = Message.create(
            conversation: conversation,
            sender: conversation.assigned_expert,
            sender_role: "expert",
            content: auto_response,
            is_read: false
          )
        end
      end

      # Trigger summary generation after 3+ messages
      if conversation.messages.count >= 3 && conversation.summary.blank?
        GenerateSummaryJob.perform_later_or_now(conversation.id)
      end

      render json: message_response(message), status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /messages/:id/read
  def mark_read
    message = Message.find_by(id: params[:id])

    unless message
      return render json: { error: "Message not found" }, status: :not_found
    end

    # Verify user has access to conversation
    conversation = message.conversation
    unless conversation.initiator == @current_user || conversation.assigned_expert == @current_user
      return render json: { error: "Conversation not found" }, status: :not_found
    end

    # Cannot mark your own messages as read
    if message.sender_id == @current_user.id
      return render json: { error: "Cannot mark your own messages as read" }, status: :forbidden
    end

    message.update(is_read: true)
    render json: { success: true }
  end

  private

  def message_response(message)
    {
      id: message.id.to_s,
      conversationId: message.conversation_id.to_s,
      senderId: message.sender_id.to_s,
      senderUsername: message.sender.username,
      senderRole: message.sender_role,
      content: message.content,
      timestamp: message.created_at.iso8601,
      isRead: message.is_read
    }
  end

end

