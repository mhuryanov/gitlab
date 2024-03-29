# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Project settings > [EE] Merge Requests', :js do
  include GitlabRoutingHelper
  include FeatureApprovalHelper

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_member) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:config_selector) { '.js-approval-rules' }
  let_it_be(:modal_selector) { '#project-settings-approvals-create-modal' }

  before do
    stub_licensed_features(compliance_approval_gates: true)
    sign_in(user)
    project.add_maintainer(user)
    group.add_developer(user)
    group.add_developer(group_member)
  end

  it 'adds approver' do
    visit edit_project_path(project)

    open_modal(text: 'Add approval rule', expand: false)
    open_approver_select

    expect(find('.select2-results')).to have_content(user.name)
    expect(find('.select2-results')).not_to have_content(non_member.name)

    find('.user-result', text: user.name).click
    close_approver_select

    expect(find('.content-list')).to have_content(user.name)

    open_approver_select

    expect(find('.select2-results')).not_to have_content(user.name)

    close_approver_select
    within('.modal-content') do
      click_button 'Add approval rule'
    end
    wait_for_requests

    expect_avatar(find('.js-members'), user)
  end

  it 'adds approver group' do
    visit edit_project_path(project)

    open_modal(text: 'Add approval rule', expand: false)
    open_approver_select

    expect(find('.select2-results')).to have_content(group.name)

    find('.user-result', text: group.name).click
    close_approver_select

    expect(find('.content-list')).to have_content(group.name)

    within('.modal-content') do
      click_button 'Add approval rule'
    end
    wait_for_requests

    expect_avatar(find('.js-members'), group.users)
  end

  context 'with an approver group' do
    let_it_be(:non_group_approver) { create(:user) }
    let_it_be(:rule) { create(:approval_project_rule, project: project, groups: [group], users: [non_group_approver]) }

    before do
      project.add_developer(non_group_approver)
    end

    it 'removes approver group' do
      visit edit_project_path(project)

      expect_avatar(find('.js-members'), rule.approvers)

      open_modal(text: 'Edit', expand: false)
      remove_approver(group.name)
      click_button "Update approval rule"
      wait_for_requests

      expect_avatar(find('.js-members'), [non_group_approver])
    end
  end

  it 'adds an approval gate' do
    visit edit_project_path(project)

    open_modal(text: 'Add approval rule', expand: false)

    within('.modal-content') do
      find('button', text: "Users or groups").click
      find('button', text: "Approval service API").click

      find('[data-qa-selector="rule_name_field"]').set('My new rule')
      find('[data-qa-selector="external_url_field"]').set('https://api.gitlab.com')

      click_button 'Add approval rule'
    end

    wait_for_requests

    expect(first('.js-name')).to have_content('My new rule')
  end

  context 'with an approval gate' do
    let_it_be(:rule) { create(:external_approval_rule, project: project) }

    it 'updates the approval gate' do
      visit edit_project_path(project)

      expect(first('.js-name')).to have_content(rule.name)

      open_modal(text: 'Edit', expand: false)

      within('.modal-content') do
        find('[data-qa-selector="rule_name_field"]').set('Something new')

        click_button 'Update approval rule'
      end

      wait_for_requests

      expect(first('.js-name')).to have_content('Something new')
    end

    it 'removes the approval gate' do
      visit edit_project_path(project)

      expect(first('.js-name')).to have_content(rule.name)

      first('.js-controls').find('[data-testid="remove-icon"]').click

      within('.modal-content') do
        click_button 'Remove approval gate'
      end

      wait_for_requests

      expect(first('.js-name')).not_to have_content(rule.name)
    end
  end

  context 'issuable default templates feature not available' do
    before do
      stub_licensed_features(issuable_default_templates: false)
    end

    it 'input to configure merge request template is not shown' do
      visit edit_project_path(project)

      expect(page).not_to have_selector('#project_merge_requests_template')
    end

    it "does not mention the merge request template in the section's description text" do
      visit edit_project_path(project)

      expect(page).to have_content('Choose your merge method, merge options, merge checks, and merge suggestions.')
    end
  end

  context 'issuable default templates feature is available' do
    before do
      stub_licensed_features(issuable_default_templates: true)
    end

    it 'input to configure merge request template is shown' do
      visit edit_project_path(project)

      expect(page).to have_selector('#project_merge_requests_template')
    end

    it "mentions the merge request template in the section's description text" do
      visit edit_project_path(project)

      expect(page).to have_content('Choose your merge method, merge options, merge checks, merge suggestions, and set up a default description template for merge requests.')
    end
  end
end
