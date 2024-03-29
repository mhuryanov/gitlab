# frozen_string_literal: true

RSpec.shared_examples 'issuable invite members experiments' do
  context 'when a privileged user can invite' do
    it 'shows a link for inviting members and launches invite modal' do
      project.add_maintainer(user)
      visit issuable_path

      find('.block.assignee .edit-link').click

      wait_for_requests

      page.within '.dropdown-menu-user' do
        expect(page).to have_link('Invite Members')
        expect(page).to have_selector('[data-track-event="click_invite_members"]')
        expect(page).to have_selector('[data-track-label="edit_assignee"]')
      end

      click_link 'Invite Members'

      expect(page).to have_content("You're inviting members to the")
    end
  end

  context 'when invite_members_version_b experiment is enabled' do
    before do
      stub_experiment_for_subject(invite_members_version_b: true)
    end

    it 'shows a link for inviting members and follows through to modal' do
      project.add_developer(user)
      visit issuable_path

      find('.block.assignee .edit-link').click

      wait_for_requests

      page.within '.dropdown-menu-user' do
        expect(page).to have_link('Invite Members', href: '#')
        expect(page).to have_selector('[data-track-event="click_invite_members_version_b"]')
        expect(page).to have_selector('[data-track-label="edit_assignee"]')
      end

      click_link 'Invite Members'

      expect(page).to have_content("Oops, this feature isn't ready yet")
    end
  end

  context 'when invite_members_version_b experiment is disabled' do
    it 'shows author in assignee dropdown and no invite link' do
      project.add_developer(user)
      visit issuable_path

      find('.block.assignee .edit-link').click

      wait_for_requests

      page.within '.dropdown-menu-user' do
        expect(page).not_to have_link('Invite Members')
      end
    end
  end
end
