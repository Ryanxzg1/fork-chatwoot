class Conversations::AssignmentService
  def initialize(conversation:, assignee_id:, assignee_type: nil)
    @conversation = conversation
    @assignee_id = assignee_id
    @assignee_type = assignee_type
  end

  def perform
    agent_bot_assignment? ? assign_agent_bot : assign_agent
  end

  private

  attr_reader :conversation, :assignee_id, :assignee_type

  def assign_agent
    conversation.with_lock do
      # Guard against a concurrent claim: if another agent just grabbed this
      # conversation while we waited for the lock, do not silently overwrite
      # their assignment. A nil assignee_id means "unassign", which is always
      # allowed.
      if assignee.present? && conversation.assignee_id.present? && conversation.assignee_id != assignee.id
        raise ActiveRecord::RecordNotSaved,
              "Conversation ##{conversation.display_id} is already assigned to agent #{conversation.assignee_id}"
      end

      if open_on_assignment? && conversation.pending?
        conversation.status = :open
        conversation.waiting_since = Time.current if conversation.waiting_since.blank?
      end
      conversation.assignee = assignee
      conversation.ai_assignee = nil
      conversation.save!
    end
    assignee
  end

  def assign_agent_bot
    assign_ai_assignee(agent_bot)
  end

  def open_on_assignment?
    assignee.present? && conversation.ai_assignee_type.present?
  end

  def assign_ai_assignee(ai_assignee)
    return unless ai_assignee

    conversation.with_lock do
      conversation.assignee = nil
      conversation.ai_assignee = ai_assignee
      conversation.status = :pending
      conversation.save!
    end
    ai_assignee
  end

  def assignee
    @assignee ||= conversation.account.users.find_by(id: assignee_id)
  end

  def agent_bot
    @agent_bot ||= AgentBot.accessible_to(conversation.account).find_by(id: assignee_id)
  end

  def agent_bot_assignment?
    assignee_type.to_s == 'AgentBot'
  end
end

