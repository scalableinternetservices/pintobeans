class ExpertAssignmentsController < ApplicationController
  # POST /conversations/:conversation_id/auto_assign
  # Manually trigger auto-assignment (if auto-assignment failed or needs reassignment)
  def auto_assign
    conversation = Conversation.find_by(id: params[:conversation_id])
    
    unless conversation
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    # Check permissions: only conversation initiator can trigger reassignment
    unless conversation.initiator_id == @current_user.id
      render json: { error: "Unauthorized" }, status: :forbidden
      return
    end

    # Trigger auto-assignment synchronously
    AutoAssignExpertJob.perform_now(conversation.id)
    
    # Reload conversation to get the assignment result
    conversation.reload
    
    render json: {
      success: true,
      message: "Auto-assignment completed.",
      assignedExpertId: conversation.assigned_expert_id&.to_s,
      assignedExpertUsername: conversation.assigned_expert&.username
    }, status: :ok
  end

  private

  def conversation_response(conversation)
    {
      id: conversation.id.to_s,
      title: conversation.title,
      status: conversation.status,
      assignedExpertId: conversation.assigned_expert_id&.to_s,
      assignedExpertUsername: conversation.assigned_expert&.username
    }
  end
end

