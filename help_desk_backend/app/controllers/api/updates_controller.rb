module Api
  class UpdatesController < ApplicationController
    # All actions require JWT authentication via Authenticatable concern
    # JWT token should be provided in Authorization header: "Bearer <token>"
    # The @current_user is set by Authenticatable#authenticate_user! which uses JwtService.decode

    # GET /api/conversations/updates
    def conversations
      since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago
      
      conversations = Conversation.for_user(@current_user)
        .where("updated_at > ?", since)
        .includes(:initiator, :assigned_expert)
        .order(updated_at: :desc)
      
      render json: conversations.map { |c| conversation_response(c) }
    end
    
    # GET /api/messages/updates
    def messages
      since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago
      
      # Get messages from user's conversations
      conversation_ids = Conversation.for_user(@current_user).pluck(:id)
      messages = Message.where(conversation_id: conversation_ids)
        .where("created_at > ?", since)
        .includes(:sender, :conversation)
        .order(created_at: :asc)
      
      render json: messages.map { |m| message_response(m) }
    end
    
    # GET /api/expert-queue/updates
    def expert_queue
      ensure_expert
      return if performed? # Exit early if ensure_expert rendered a response
      
      since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago
      
      waiting = Conversation.waiting
        .where("updated_at > ?", since)
        .includes(:initiator)
        .order(created_at: :desc)
        .map { |c| conversation_response(c) }
      
      assigned = Conversation.assigned_to(@current_user)
        .where("updated_at > ?", since)
        .includes(:initiator, :assigned_expert)
        .order(updated_at: :desc)
        .map { |c| conversation_response(c) }
      
      render json: {
        waitingConversations: waiting,
        assignedConversations: assigned
      }
    end
    
    private
    
    def ensure_expert
      unless @current_user&.expert_profile
        render json: { error: "Expert profile required" }, status: :forbidden
      end
    end
    
    def conversation_response(conversation)
      {
        id: conversation.id.to_s,
        title: conversation.title,
        status: conversation.status,
        questionerId: conversation.initiator_id.to_s,
        questionerUsername: conversation.initiator.username,
        assignedExpertId: conversation.assigned_expert_id&.to_s,
        assignedExpertUsername: conversation.assigned_expert&.username,
        createdAt: conversation.created_at.iso8601,
        updatedAt: conversation.updated_at.iso8601,
        lastMessageAt: conversation.last_message_at&.iso8601,
        unreadCount: conversation.unread_count_for(@current_user)
      }
    end
    
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
end

