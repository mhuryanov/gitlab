# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project members list', :js do
  include Select2Helper
  include Spec::Support::Helpers::Features::MembersHelpers

  let(:user1) { create(:user, name: 'John Doe') }
  let(:user2) { create(:user, name: 'Mary Jane') }
  let(:group) { create(:group) }
  let(:project) { create(:project, :internal, namespace: group) }

  before do
    stub_feature_flags(invite_members_group_modal: true)

    sign_in(user1)
    group.add_owner(user1)
  end

  it 'show members from project and group' do
    project.add_developer(user2)

    visit_members_page

    expect(first_row).to have_content(user1.name)
    expect(second_row).to have_content(user2.name)
  end

  it 'show user once if member of both group and project' do
    project.add_developer(user1)

    visit_members_page

    expect(first_row).to have_content(user1.name)
    expect(second_row).to be_blank
  end

  it 'update user access level' do
    project.add_developer(user2)

    visit_members_page

    page.within find_member_row(user2) do
      click_button('Developer')
      click_button('Reporter')

      expect(page).to have_button('Reporter')
    end
  end

  it 'add user to project' do
    visit_members_page

    add_user(user2.name, 'Reporter')

    page.within find_member_row(user2) do
      expect(page).to have_button('Reporter')
    end
  end

  it 'uses ProjectMember access_level_roles for the invite members modal access option' do
    visit_members_page

    click_on 'Invite members'

    click_on 'Guest'
    wait_for_requests

    page.within '.dropdown-menu' do
      expect(page).to have_button('Guest')
      expect(page).to have_button('Reporter')
      expect(page).to have_button('Developer')
      expect(page).to have_button('Maintainer')
      expect(page).not_to have_button('Owner')
    end
  end

  it 'remove user from project' do
    other_user = create(:user)
    project.add_developer(other_user)

    visit_members_page

    # Open modal
    page.within find_member_row(other_user) do
      click_button 'Remove member'
    end

    page.within('[role="dialog"]') do
      expect(page).to have_unchecked_field 'Also unassign this user from related issues and merge requests'
      click_button('Remove member')
    end

    wait_for_requests

    expect(members_table).not_to have_content(other_user.name)
  end

  it 'invite user to project' do
    visit_members_page

    add_user('test@example.com', 'Reporter')

    click_link 'Invited'

    page.within find_invited_member_row('test@example.com') do
      expect(page).to have_button('Reporter')
    end
  end

  context 'project bots' do
    let(:project_bot) { create(:user, :project_bot, name: 'project_bot') }

    before do
      project.add_maintainer(project_bot)
    end

    it 'does not show form used to change roles and "Expiration date" or the remove user button' do
      visit_members_page

      page.within find_member_row(project_bot) do
        expect(page).not_to have_button('Maintainer')
        expect(page).to have_field('Expiration date', disabled: true)
        expect(page).not_to have_button('Remove member')
      end
    end
  end

  describe 'when user has 2FA enabled' do
    let_it_be(:admin) { create(:admin) }
    let_it_be(:user_with_2fa) { create(:user, :two_factor_via_otp) }

    before do
      project.add_guest(user_with_2fa)
    end

    it 'shows 2FA badge to user with "Maintainer" access level' do
      project.add_maintainer(user1)

      visit_members_page

      expect(find_member_row(user_with_2fa)).to have_content('2FA')
    end

    it 'shows 2FA badge to admins' do
      sign_in(admin)
      gitlab_enable_admin_mode_sign_in(admin)

      visit_members_page

      expect(find_member_row(user_with_2fa)).to have_content('2FA')
    end

    it 'does not show 2FA badge to users with access level below "Maintainer"' do
      group.add_developer(user1)

      visit_members_page

      expect(find_member_row(user_with_2fa)).not_to have_content('2FA')
    end

    it 'shows 2FA badge to themselves' do
      sign_in(user_with_2fa)

      visit_members_page

      expect(find_member_row(user_with_2fa)).to have_content('2FA')
    end
  end

  private

  def add_user(id, role)
    click_on 'Invite members'

    page.within '#invite-members-modal' do
      fill_in 'Select members or type email addresses', with: id

      wait_for_requests
      click_button id

      click_button 'Guest'
      wait_for_requests
      click_button role

      click_button 'Invite'
    end

    page.refresh
  end

  def visit_members_page
    visit project_project_members_path(project)
  end
end
