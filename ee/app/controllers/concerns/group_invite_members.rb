# frozen_string_literal: true

module GroupInviteMembers
  private

  def invite_members(group)
    invite_params = {
      user_ids: emails_param[:emails].reject(&:blank?).join(','),
      access_level: Gitlab::Access::DEVELOPER
    }

    Members::CreateService.new(current_user, invite_params).execute(group)
  end

  def emails_param
    params.require(:group).permit(emails: [])
  end
end