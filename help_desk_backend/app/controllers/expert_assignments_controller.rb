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

    # Trigger auto-assignment in background
    AutoAssignExpertJob.perform_later(conversation.id)
    
    render json: {
      success: true,
      message: "Auto-assignment job has been queued. The conversation will be assigned shortly."
    }, status: :accepted
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

