class ConversationsController < ApplicationController
  # All actions require JWT authentication via Authenticatable concern
  # JWT token should be provided in Authorization header: "Bearer <token>"
  # The @current_user is set by Authenticatable#authenticate_user! which uses JwtService.decode
  # Authentication is automatically applied via ApplicationController's inclusion of Authenticatable

    # GET /conversations
    def index
        conversations = Conversation.for_user(@current_user)
        .includes(:initiator, :assigned_expert)
        .order(updated_at: :desc)

        render json: conversations.map { |c| conversation_response(c) }
    end

    # GET /conversations/:id
    def show
        conversation = Conversation.for_user(@current_user).find_by(id: params[:id])

        if conversation
            render json: conversation_response(conversation)
        else
            render json: { error: "Conversation not found" }, status: :not_found
        end
    end

    # POST /conversations
    def create
        conversation = Conversation.new(conversation_params)
        conversation.initiator = @current_user
        conversation.status ||= "waiting"
        conversation.last_message_at = Time.current

        if conversation.save
            # Trigger auto-assignment synchronously
            AutoAssignExpertJob.perform_now(conversation.id)
            
            # Reload conversation to get the assignment result
            conversation.reload
            
            render json: conversation_response(conversation), status: :created
        else
            render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
        end
    end

    private

    def conversation_params
        params.permit(:title, :status)
    end

    def conversation_response(conversation)
        # Generate or queue summary generation if needed
        if conversation.summary.blank? && conversation.messages.count > 0
            GenerateSummaryJob.perform_later_or_now(conversation.id)
            conversation.reload
        end

        {
            id: conversation.id.to_s,
            title: conversation.title,
            status: conversation.status,
            questionerId: conversation.initiator_id.to_s,
            questionerUsername: conversation.initiator.username,
            questionerUsernameWithId: "#{conversation.initiator.username}##{conversation.initiator.id}",
            assignedExpertId: conversation.assigned_expert_id&.to_s,
            assignedExpertUsername: conversation.assigned_expert&.username,
            assignedExpertUsernameWithId: (
             conversation.assigned_expert ? "#{conversation.assigned_expert.username}##{conversation.assigned_expert.id}" : nil
         ),
            createdAt: conversation.created_at.iso8601,
            updatedAt: conversation.updated_at.iso8601,
            lastMessageAt: conversation.last_message_at&.iso8601,
            unreadCount: conversation.unread_count_for(@current_user),
            summary: conversation.summary
        }
    end
end