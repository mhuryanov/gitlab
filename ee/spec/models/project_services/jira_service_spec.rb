# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JiraService do
  let(:jira_service) { build(:jira_service, **options) }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  let(:options) do
    {
      url: 'http://jira.example.com',
      username: 'gitlab_jira_username',
      password: 'gitlab_jira_password',
      project_key: 'GL'
    }
  end

  before do
    allow(jira_service.data_fields).to receive(:deployment_cloud?).and_return(true)
    allow(jira_service.data_fields).to receive(:deployment_server?).and_return(false)
  end

  describe 'validations' do
    it 'validates presence of project_key if issues_enabled' do
      jira_service.project_key = ''
      jira_service.issues_enabled = true

      expect(jira_service).to be_invalid
    end

    it 'validates presence of project_key if vulnerabilities_enabled' do
      jira_service.project_key = ''
      jira_service.vulnerabilities_enabled = true

      expect(jira_service).to be_invalid
    end

    it 'validates presence of vulnerabilities_issuetype if vulnerabilities_enabled' do
      jira_service.vulnerabilities_issuetype = ''
      jira_service.vulnerabilities_enabled = true

      expect(jira_service).to be_invalid
    end
  end

  describe 'jira_vulnerabilities_integration_enabled?' do
    subject(:jira_vulnerabilities_integration_enabled) { jira_service.jira_vulnerabilities_integration_enabled? }

    context 'when integration is not configured for the project' do
      let(:options) { { project: nil } }

      it { is_expected.to be_falsey }
    end

    context 'when jira integration is not available for the project' do
      before do
        stub_feature_flags(jira_for_vulnerabilities: false)
      end

      context 'when vulnerabilities_enabled is set to false' do
        it { is_expected.to be_falsey }
      end

      context 'when vulnerabilities_enabled is set to true' do
        before do
          jira_service.vulnerabilities_enabled = true
        end

        it { is_expected.to eq(false) }
      end
    end

    context 'when jira integration is available for the project' do
      before do
        stub_licensed_features(jira_vulnerabilities_integration: true)
      end

      context 'when vulnerabilities_enabled is set to false' do
        it { is_expected.to be_falsey }
      end

      context 'when vulnerabilities_enabled is set to true' do
        before do
          jira_service.vulnerabilities_enabled = true
        end

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '#test' do
    let(:jira_service) { described_class.new(options) }

    subject(:jira_test) { jira_service.test(nil) }

    context 'when server is not responding' do
      before do
        allow(jira_service).to receive(:server_info).and_return(nil)
      end

      it { is_expected.to eq(success: false, result: nil) }
    end

    context 'when server is responding' do
      before do
        allow(jira_service).to receive(:server_info).and_return({ jira: true })
      end

      context 'when vulnerabilities integration is not enabled' do
        before do
          allow(jira_service.project).to receive(:jira_vulnerabilities_integration_enabled?).and_return(false)
        end

        it { is_expected.to eq(success: true, result: { jira: true }) }
      end

      context 'when vulnerabilities integration is enabled' do
        before do
          allow(jira_service.project).to receive(:jira_vulnerabilities_integration_enabled?).and_return(true)
        end

        context 'when deployment type is cloud' do
          let(:project_info_result) { { 'id' => '10000' } }

          let(:issue_type_scheme_response) do
            {
              values: [
                {
                  issueTypeScheme: {
                    id: '10126',
                    name: 'GV: Software Development Issue Type Scheme',
                    defaultIssueTypeId: '10001'
                  },
                  projectIds: [
                    '10000'
                  ]
                }
              ]
            }
          end

          let(:issue_type_mapping_response) do
            {
              values: [
                {
                  issueTypeSchemeId: '10126',
                  issueTypeId: '10003'
                },
                {
                  issueTypeSchemeId: '10126',
                  issueTypeId: '10001'
                }
              ]
            }
          end

          let(:issue_types_response) do
            [
              {
                id: '10004',
                description: 'A new feature of the product, which has yet to be developed.',
                name: 'New Feature',
                untranslatedName: 'New Feature',
                subtask: false,
                avatarId: 10311
              },
              {
                id: '10001',
                description: 'Jira Bug',
                name: 'Bug',
                untranslatedName: 'Bug',
                subtask: false,
                avatarId: 10303
              },
              {
                id: '10003',
                description: 'A small piece of work thats part of a larger task.',
                name: 'Sub-task',
                untranslatedName: 'Sub-task',
                subtask: true,
                avatarId: 10316
              }
            ]
          end

          before do
            WebMock.stub_request(:get, /api\/2\/project\/GL/).with(basic_auth: %w(gitlab_jira_username gitlab_jira_password)).to_return(body: project_info_result.to_json )
            WebMock.stub_request(:get, /api\/2\/project\/GL\z/).with(basic_auth: %w(gitlab_jira_username gitlab_jira_password)).to_return(body: { 'id' => '10000' }.to_json, headers: headers)
            WebMock.stub_request(:get, /api\/2\/issuetype\z/).to_return(body: issue_types_response.to_json, headers: headers)
            WebMock.stub_request(:get, /api\/2\/issuetypescheme\/project\?projectId\=10000\z/).to_return(body: issue_type_scheme_response.to_json, headers: headers)
            WebMock.stub_request(:get, /api\/2\/issuetypescheme\/mapping\?issueTypeSchemeId\=10126\z/).to_return(body: issue_type_mapping_response.to_json, headers: headers)
          end

          it { is_expected.to eq(success: true, result: { jira: true }, data: { issuetypes: [{ id: '10001', name: 'Bug', description: 'Jira Bug' }] }) }
        end

        context 'when deployment type is server' do
          let(:project_info_result) do
            {
              "id": "10000",
              "issueTypes": issue_types_response
            }
          end

          let(:issue_types_response) do
            [
              {
                "avatarId": 10318,
                "description": "A task that needs to be done.",
                "iconUrl": "http://jira.reali.sh:8080/secure/viewavatar?size=xsmall&avatarId=10318&avatarType=issuetype",
                "id": "10003",
                "name": "Task",
                "self": "http://jira.reali.sh:8080/rest/api/2/issuetype/10003",
                "subtask": false
              },
              {
                "description": "The sub-task of the issue",
                "iconUrl": "http://jira.reali.sh:8080/images/icons/issuetypes/subtask_alternate.png",
                "id": "10000",
                "name": "Sub-task",
                "self": "http://jira.reali.sh:8080/rest/api/2/issuetype/10000",
                "subtask": true
              },
              {
                "description": "Created by Jira Software - do not edit or delete. Issue type for a user story.",
                "iconUrl": "http://jira.reali.sh:8080/images/icons/issuetypes/story.svg",
                "id": "10002",
                "name": "Story",
                "self": "http://jira.reali.sh:8080/rest/api/2/issuetype/10002",
                "subtask": false
              },
              {
                "avatarId": 10303,
                "description": "A problem which impairs or prevents the functions of the product.",
                "iconUrl": "http://jira.reali.sh:8080/secure/viewavatar?size=xsmall&avatarId=10303&avatarType=issuetype",
                "id": "10004",
                "name": "Bug",
                "self": "http://jira.reali.sh:8080/rest/api/2/issuetype/10004",
                "subtask": false
              },
              {
                "description": "Created by Jira Software - do not edit or delete. Issue type for a big user story that needs to be broken down.",
                "iconUrl": "http://jira.reali.sh:8080/images/icons/issuetypes/epic.svg",
                "id": "10001",
                "name": "Epic",
                "self": "http://jira.reali.sh:8080/rest/api/2/issuetype/10001",
                "subtask": false
              }
            ]
          end

          before do
            allow(jira_service.data_fields).to receive(:deployment_cloud?).and_return(false)
            allow(jira_service.data_fields).to receive(:deployment_server?).and_return(true)

            WebMock.stub_request(:get, /api\/2\/project\/GL/).with(basic_auth: %w(gitlab_jira_username gitlab_jira_password)).to_return(body: project_info_result.to_json, headers: headers)
            WebMock.stub_request(:get, /api\/2\/issuetype\z/).to_return(body: issue_types_response.to_json, headers: headers)
          end

          it { is_expected.to eq(success: true, result: { jira: true }, data: { issuetypes: [{ description: "A task that needs to be done.", id: "10003", name: "Task" }, { description: "Created by Jira Software - do not edit or delete. Issue type for a user story.", id: "10002", name: "Story" }, { description: "A problem which impairs or prevents the functions of the product.", id: "10004", name: "Bug" }, { description: "Created by Jira Software - do not edit or delete. Issue type for a big user story that needs to be broken down.", id: "10001", name: "Epic" }] }) }
        end
      end
    end
  end

  describe '#create_issue' do
    let(:jira_service) { described_class.new(options) }
    let(:issue_info) { { 'id': '10000' } }

    before do
      allow(jira_service).to receive(:jira_project_id).and_return('11223')
      allow(jira_service).to receive(:vulnerabilities_issuetype).and_return('10001')
    end

    context 'when there is no issues in Jira API' do
      before do
        WebMock.stub_request(:post, 'http://jira.example.com/rest/api/2/issue').with(basic_auth: %w(gitlab_jira_username gitlab_jira_password)).to_return(body: issue_info.to_json)
      end

      it 'creates issue in Jira API' do
        issue = jira_service.create_issue("Special Summary!?", "*ID*: 2\n_Issue_: !", build(:user))

        expect(WebMock).to have_requested(:post, 'http://jira.example.com/rest/api/2/issue').with(
          body: { fields: { project: { id: '11223' }, issuetype: { id: '10001' }, summary: 'Special Summary!?', description: "*ID*: 2\n_Issue_: !" } }.to_json
        ).once
        expect(issue.id).to eq('10000')
      end

      it 'tracks usage' do
        user = build_stubbed(:user)

        expect(Gitlab::UsageDataCounters::HLLRedisCounter)
          .to receive(:track_event)
          .with('i_ecosystem_jira_service_create_issue', values: user.id)

        jira_service.create_issue('x', 'y', user)
      end
    end

    context 'when there is an error in Jira' do
      let(:errors) { { 'errorMessages' => [], 'errors' => { 'summary' => 'You must specify a summary of the issue.' } } }

      before do
        WebMock.stub_request(:post, 'http://jira.example.com/rest/api/2/issue').with(basic_auth: %w(gitlab_jira_username gitlab_jira_password)).to_return(status: [400, 'Bad Request'], body: errors.to_json)
      end

      it 'returns issue with errors' do
        issue = jira_service.create_issue('', "*ID*: 2\n_Issue_: !", build(:user))

        expect(WebMock).to have_requested(:post, 'http://jira.example.com/rest/api/2/issue').with(
          body: { fields: { project: { id: '11223' }, issuetype: { id: '10001' }, summary: '', description: "*ID*: 2\n_Issue_: !" } }.to_json
        ).once
        expect(issue.errors).to eq('summary' => 'You must specify a summary of the issue.')
      end
    end
  end

  describe '#configured_to_create_issues_from_vulnerabilities?' do
    subject(:configured_to_create_issues_from_vulnerabilities) { jira_service.configured_to_create_issues_from_vulnerabilities? }

    context 'when is not active' do
      before do
        allow(jira_service).to receive(:active?).and_return(false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when is active' do
      before do
        allow(jira_service).to receive(:active?).and_return(true)
      end

      context 'and jira_vulnerabilities_integration is disabled' do
        before do
          allow(jira_service).to receive(:jira_vulnerabilities_integration_enabled?).and_return(false)
        end

        it { is_expected.to be_falsey }
      end

      context 'and jira_vulnerabilities_integration is enabled' do
        before do
          allow(jira_service).to receive(:jira_vulnerabilities_integration_enabled?).and_return(true)
        end

        context 'and project key is missing' do
          before do
            allow(jira_service).to receive(:project_key).and_return('')
          end

          it { is_expected.to be_falsey }
        end

        context 'and project key is not missing' do
          before do
            allow(jira_service).to receive(:project_key).and_return('GV')
          end

          context 'and vulnerabilities issue type is missing' do
            before do
              allow(jira_service).to receive(:vulnerabilities_issuetype).and_return('')
            end

            it { is_expected.to be_falsey }
          end

          context 'and vulnerabilities issue type is not missing' do
            before do
              allow(jira_service).to receive(:vulnerabilities_issuetype).and_return('10001')
            end

            it { is_expected.to be_truthy }
          end
        end
      end
    end
  end

  describe '#new_issue_url_with_predefined_fields' do
    before do
      allow(jira_service).to receive(:jira_project_id).and_return('11223')
      allow(jira_service).to receive(:vulnerabilities_issuetype).and_return('10001')
    end

    let(:expected_new_issue_url) { '/secure/CreateIssueDetails!init.jspa?pid=11223&issuetype=10001&summary=Special+Summary%21%3F&description=%2AID%2A%3A+2%0A_Issue_%3A+%21' }

    subject(:new_issue_url) { jira_service.new_issue_url_with_predefined_fields("Special Summary!?", "*ID*: 2\n_Issue_: !") }

    it { is_expected.to eq(expected_new_issue_url) }
  end
end
