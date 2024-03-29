# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Members > Owner adds member with expiration date', :js do
  include Select2Helper
  include Spec::Support::Helpers::Features::MembersHelpers

  let_it_be(:user1) { create(:user, name: 'John Doe') }
  let_it_be(:group) { create(:group) }

  let(:new_member) { create(:user, name: 'Mary Jane') }

  before do
    stub_feature_flags(invite_members_group_modal: false)
    group.add_owner(user1)
    sign_in(user1)
  end

  it 'expiration date is displayed in the members list' do
    visit group_group_members_path(group)

    page.within invite_users_form do
      select2(new_member.id, from: '#user_ids', multiple: true)

      fill_in 'expires_at', with: 5.days.from_now.to_date
      find_field('expires_at').native.send_keys :enter

      click_on 'Invite'
    end

    page.within second_row do
      expect(page).to have_content(/in \d days/)
    end
  end

  it 'changes expiration date' do
    group.add_developer(new_member)
    visit group_group_members_path(group)

    page.within second_row do
      fill_in 'Expiration date', with: 5.days.from_now.to_date
      find_field('Expiration date').native.send_keys :enter

      wait_for_requests

      expect(page).to have_content(/in \d days/)
    end
  end

  it 'clears expiration date' do
    create(:group_member, :developer, user: new_member, group: group, expires_at: 5.days.from_now.to_date)
    visit group_group_members_path(group)

    page.within second_row do
      expect(page).to have_content(/in \d days/)

      find('[data-testid="clear-button"]').click

      wait_for_requests

      expect(page).to have_content('No expiration set')
    end
  end
end
