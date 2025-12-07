class ExpertsController < ApplicationController

  # RUBY NOTES for Katie and Che:
  # @expert_profile.update(expert_profile_params) tries to set those values on the expert profile and save them to the database
  # .update! means an error is returned on fail, not just "false"

  # authenticates expert with JWT token
  before_action :authenticate_expert

  # GET /expert/queue: get the expert queue (waiting and assigned conversations)
  def queue
    cache_key = [
      "expert_queue_waiting",
      Conversation.where(assigned_expert_id: nil, status: "waiting").maximum(:updated_at)
    ].compact.join("/")

    waiting_conversations = Rails.cache.fetch(cache_key, expires_in: 10.seconds) do
      # Only runs on cache MISS
      Conversation
        .where(assigned_expert_id: nil, status: "waiting")
        .includes(:initiator)
        .to_a
        .map { |c| serialize_conversation(c) }
    end

    # Always fetch assigned conversations fresh (not cached)
    assigned = Conversation
                .where(assigned_expert_id: @expert_profile.user_id)
                .includes(:initiator, :assigned_expert)
                .to_a

    render json: {
      waitingConversations: waiting_conversations,
      assignedConversations: assigned.map { |c| serialize_conversation(c) }
    }
  end


  private

  def serialize_conversation(convo)
    {
      id: convo.id.to_s,
      title: convo.title,
      status: convo.status,
      questionerId: convo.initiator_id.to_s,
      questionerUsername: convo.initiator.username,
      assignedExpertId: convo.assigned_expert_id&.to_s,
      assignedExpertUsername: convo.assigned_expert&.username,
      createdAt: convo.created_at.iso8601,
      updatedAt: convo.updated_at.iso8601,
      lastMessageAt: convo.last_message_at&.iso8601
    }
  end

  # POST /expert/conversations/:conversation_id/claim: claim a conversation as an expert.
  def claim

    # get the conversation given the conversation_id
    conversation = Conversation.find(params[:conversation_id])

    # check if conversation already has an expert assigned
    if conversation.assigned_expert.present?
      render json: { error: "Conversation is already assigned to an expert" },
             status: :unprocessable_entity
      return
    end

    #user = User.find(params[:expert_profile.user_id])

    # update expert's conversation_id to the id of the conversation being claimed
    conversation.update!(
      assigned_expert: @expert_profile.user,
      status: "active"
    )

    # make Expert Assignment object to store this assignment
    ExpertAssignment.create!(
      conversation: conversation,
      expert_id: @expert_profile.id,
      status: "active",
      assigned_at: Time.current
    )

    render json: { success: true }

  end

  # POST /expert/conversations/:conversation_id/unclaim: unclaim a conversation (return it to the waiting queue).
  def unclaim

    # get the conversation given the conversation_id
    conversation = Conversation.find(params[:conversation_id])

    # check if conversation is assigned to the current expert
    unless conversation.assigned_expert.id == @expert_profile.user_id
      render json: { error: "Current expert is not assigned to this conversation" },
        status: :forbidden
      return
    end

    # remove the expert's id from the conversation and change status
    conversation.update!(assigned_expert: nil, status: "waiting")

    # update the expert assignment to mark it resolved
    assignment = ExpertAssignment.where(conversation: conversation, expert_id: @expert_profile).order(assigned_at: :desc).first

    if assignment
      assignment.update!(status: "resolved", resolved_at: Time.current)
    end

    render json: { success: true }

  end

  # GET /expert/profile: get the current expert's profile.
  # def show
  #   render json: @expert_profile
  # end

  def show
    profile = @expert_profile
    render json: {
      id: profile.id,
      bio: profile.bio,
      knowledgeBaseLinks: profile.knowledge_base_links.presence || [],
      faq: profile.faq.presence || []
    }
  end

  # PUT /expert/profile: update the expert's profile.
  def update

    # if @expert_profile.update(expert_profile_params)
    #   render json: @expert_profile
    # else
    #   render json: { errors: @expert_profile.errors.full_messages }, status: :unprocessable_entity
    # end

    if @expert_profile.update(expert_profile_params)
      render json: {
        id: @expert_profile.id,
        bio: @expert_profile.bio,
        knowledgeBaseLinks: @expert_profile.knowledge_base_links.presence,
        faq: @expert_profile.faq.presence || []
      }
    else
      render json: { errors: @expert_profile.errors.full_messages }, status: :unprocessable_entity
    end

  end

  # GET /expert/assignments/history: get the expert's assignment history.
  def history
    assignments = ExpertAssignment
                  .where(expert_id: @expert_profile.id)
                  .order(assigned_at: :desc)

    render json: assignments.map { |a| format_assignment(a) }
  end

  private

  # authenticates expert with JWT token
  def authenticate_expert

    token = request.headers["Authorization"]&.split(" ")&.last

    payload = JwtService.decode(token).with_indifferent_access
    @current_user = User.find_by(id: payload[:user_id])

    if @current_user.nil?
      return render json: { error: "Current user = nil" }, status: :forbidden
    end

    @expert_profile = ExpertProfile.find_by(user_id: @current_user.id)

    if @expert_profile.nil?
      return render json: { error: "Not authorized as expert" }, status: :forbidden
    end

  end

  def expert_profile_params
    params.require(:expert_profile).permit(
      :bio,
      knowledge_base_links: [],
      faq: [:question, :answer]
    )
  end

  def format_assignment(assignment)
    {
      id: assignment.id.to_s,
      conversationId: assignment.conversation_id.to_s,
      expertId: assignment.expert_id.to_s,
      status: assignment.status.downcase,   # optional: normalize to lowercase
      assignedAt: assignment.assigned_at.iso8601,
      resolvedAt: assignment.resolved_at&.iso8601,
      rating: assignment.respond_to?(:rating) ? assignment.rating : nil
    }
  end

end
