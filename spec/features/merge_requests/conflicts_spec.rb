require 'spec_helper'

feature 'Merge request conflict resolution', js: true, feature: true do
  include WaitForAjax

  let(:user) { create(:user) }
  let(:project) { create(:project) }

  def create_merge_request(source_branch)
    create(:merge_request, source_branch: source_branch, target_branch: 'conflict-start', source_project: project) do |mr|
      mr.mark_as_unmergeable
    end
  end

  context 'when a merge request can be resolved in the UI' do
    let(:merge_request) { create_merge_request('conflict-resolvable') }

    before do
      project.team << [user, :developer]
      login_as(user)

      visit namespace_project_merge_request_path(project.namespace, project, merge_request)
    end

    it 'shows a link to the conflict resolution page' do
      expect(page).to have_link('conflicts', href: /\/conflicts\Z/)
    end

    context 'visiting the conflicts resolution page' do
      before { click_link('conflicts', href: /\/conflicts\Z/) }

      it 'shows the conflicts' do
        begin
          expect(find('#conflicts')).to have_content('popen.rb')
        rescue Capybara::Poltergeist::JavascriptError
          retry
        end
      end

      context 'when in inline mode' do
        it 'resolves files manually' do
          within find('.files-wrapper .diff-file.inline-view', text: 'files/ruby/popen.rb') do
            click_button 'Edit inline'
            wait_for_ajax
            execute_script('ace.edit($(".files-wrapper .diff-file.inline-view pre")[0]).setValue("One morning");')
          end

          within find('.files-wrapper .diff-file', text: 'files/ruby/regex.rb') do
            click_button 'Edit inline'
            wait_for_ajax
            execute_script('ace.edit($(".files-wrapper .diff-file.inline-view pre")[1]).setValue("Gregor Samsa woke from troubled dreams");')
          end

          click_button 'Commit conflict resolution'
          wait_for_ajax
          expect(page).to have_content('All merge conflicts were resolved')
          merge_request.reload_diff

          click_on 'Changes'
          wait_for_ajax

          expect(page).to have_content('One morning')
          expect(page).to have_content('Gregor Samsa woke from troubled dreams')
        end
      end
    end
  end

  UNRESOLVABLE_CONFLICTS = {
    'conflict-too-large' => 'when the conflicts contain a large file',
    'conflict-binary-file' => 'when the conflicts contain a binary file',
    'conflict-missing-side' => 'when the conflicts contain a file edited in one branch and deleted in another',
    'conflict-non-utf8' => 'when the conflicts contain a non-UTF-8 file',
  }

  UNRESOLVABLE_CONFLICTS.each do |source_branch, description|
    context description do
      let(:merge_request) { create_merge_request(source_branch) }

      before do
        project.team << [user, :developer]
        login_as(user)

        visit namespace_project_merge_request_path(project.namespace, project, merge_request)
      end

      it 'does not show a link to the conflict resolution page' do
        expect(page).not_to have_link('conflicts', href: /\/conflicts\Z/)
      end

      it 'shows an error if the conflicts page is visited directly' do
        visit current_url + '/conflicts'
        wait_for_ajax

        expect(find('#conflicts')).to have_content('Please try to resolve them locally.')
      end
    end
  end
end
