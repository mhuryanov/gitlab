# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic boards sidebar', :js do
  include BoardHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }

  let_it_be(:bug) { create(:group_label, group: group, name: 'Bug') }
  let_it_be(:epic_board) { create(:epic_board, group: group) }
  let_it_be(:backlog_list) { create(:epic_list, epic_board: epic_board, list_type: :backlog) }
  let_it_be(:closed_list) { create(:epic_list, epic_board: epic_board, list_type: :closed) }
  let_it_be(:epic1) { create(:epic, group: group, title: 'Epic1') }

  let(:card) { find('.board:nth-child(1)').first("[data-testid='board_card']") }

  before do
    stub_licensed_features(epics: true)
    group.add_maintainer(user)
    sign_in(user)
    visit group_epic_boards_path(group)
    wait_for_requests
  end

  it 'shows sidebar when clicking epic' do
    click_card(card)

    expect(page).to have_selector('[data-testid="epic-boards-sidebar"]')
  end

  it 'closes sidebar when clicking epic' do
    click_card(card)

    expect(page).to have_selector('[data-testid="epic-boards-sidebar"]')

    click_card(card)

    expect(page).not_to have_selector('[data-testid="epic-boards-sidebar"]')
  end

  it 'closes sidebar when clicking close button' do
    click_card(card)

    expect(page).to have_selector('[data-testid="epic-boards-sidebar"]')

    find('.gl-drawer-close-button [data-testid="close-icon"]').click

    expect(page).not_to have_selector('[data-testid="epic-boards-sidebar"]')
  end

  it 'shows epic details when sidebar is open', :aggregate_failures do
    click_card(card)

    page.within('[data-testid="epic-boards-sidebar"]') do
      expect(page).to have_content(epic1.title)
      expect(page).to have_content(epic1.to_reference)
    end
  end

  context 'title' do
    it 'edits epic title' do
      click_card(card)

      page.within('[data-testid="sidebar-title"]') do
        click_button 'Edit'

        wait_for_requests

        find('input').set('Test title')

        click_button 'Save changes'

        wait_for_requests

        expect(page).to have_content('Test title')
      end

      expect(card).to have_content('Test title')
    end
  end

  context 'labels' do
    it 'adds a single label' do
      click_card(card)

      page.within('.labels') do
        click_button 'Edit'

        wait_for_requests

        click_link bug.title

        find('[data-testid="close-icon"]').click

        wait_for_requests

        page.within('.value') do
          expect(page).to have_selector('.gl-label-text', count: 1)
          expect(page).to have_content(bug.title)
        end
      end

      expect(card).to have_selector('.gl-label', count: 1)
      expect(card).to have_content(bug.title)
    end
  end

  context 'confidentiality' do
    it 'make epic confidential' do
      click_card(card)

      page.within('.confidentiality') do
        expect(page).to have_content('Not confidential')

        click_button 'Edit'
        expect(page).to have_css('.sidebar-item-warning-message')

        within('.sidebar-item-warning-message') do
          click_button 'Turn on'
        end

        wait_for_requests

        expect(page).to have_content('This epic is confidential')
      end
    end
  end

  context 'in notifications subscription' do
    it 'displays notifications toggle', :aggregate_failures do
      click_card(card)

      page.within('[data-testid="sidebar-notifications"]') do
        expect(page).to have_button('Notifications')
        expect(page).not_to have_content('Notifications have been disabled by the project or group owner')
      end
    end

    it 'shows toggle as on then as off as user toggles to subscribe and unsubscribe', :aggregate_failures do
      click_card(card)

      click_button 'Notifications'

      expect(page).to have_button('Notifications', class: 'is-checked')

      click_button 'Notifications'

      expect(page).not_to have_button('Notifications', class: 'is-checked')
    end

    context 'when notifications have been disabled' do
      before do
        group.update_attribute(:emails_disabled, true)

        refresh_and_click_first_card
      end

      it 'displays a message that notifications have been disabled' do
        page.within('[data-testid="sidebar-notifications"]') do
          expect(page).not_to have_selector('[data-testid="notification-subscribe-toggle"]')
          expect(page).to have_content('Notifications have been disabled by the project or group owner')
        end
      end
    end
  end

  def refresh_and_click_first_card
    page.refresh

    wait_for_requests

    click_card(card)
  end
end
