# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting Alert Management HTTP Integrations' do
  include ::Gitlab::Routing.url_helpers
  include GraphqlHelpers

  let_it_be(:payload_example) do
    {
      alert: {
        desc: 'Alert description',
        name: 'Alert name'
      }
    }
  end

  let_it_be(:payload_attribute_mapping) do
    {
      title: { path: %w(alert name), type: 'string' },
      description: { path: %w(alert desc), type: 'string', label: 'Description' }
    }
  end

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:prometheus_service) { create(:prometheus_service, project: project) }
  let_it_be(:project_alerting_setting) { create(:project_alerting_setting, project: project) }
  let_it_be(:inactive_http_integration) { create(:alert_management_http_integration, :inactive, project: project) }
  let_it_be(:other_project_http_integration) { create(:alert_management_http_integration) }
  let_it_be(:active_http_integration) do
    create(
      :alert_management_http_integration,
      project: project,
      payload_example: payload_example,
      payload_attribute_mapping: payload_attribute_mapping
    )
  end

  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('AlertManagementHttpIntegration')}
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('alertManagementHttpIntegrations', {}, fields)
    )
  end

  before do
    stub_licensed_features(multiple_alert_http_integrations: true)
  end

  before_all do
    project.add_developer(developer)
    project.add_maintainer(maintainer)
  end

  context 'with integrations' do
    let(:integrations) { graphql_data.dig('project', 'alertManagementHttpIntegrations', 'nodes') }

    context 'without project permissions' do
      let(:current_user) { guest }

      before do
        post_graphql(query, current_user: current_user)
      end

      it_behaves_like 'a working graphql query'

      specify { expect(integrations).to be_nil }
    end

    context 'with developer permissions' do
      let(:current_user) { developer }

      before do
        post_graphql(query, current_user: current_user)
      end

      it_behaves_like 'a working graphql query'

      specify { expect(integrations).to eq([]) }
    end

    context 'with maintainer permissions' do
      let(:current_user) { maintainer }

      before do
        post_graphql(query, current_user: current_user)
      end

      it_behaves_like 'a working graphql query'

      specify { expect(integrations.size).to eq(2) }

      it 'returns the correct properties of the integrations' do
        expect(integrations).to include(
          {
            'id' => GitlabSchema.id_from_object(active_http_integration).to_s,
            'type' => 'HTTP',
            'name' => active_http_integration.name,
            'active' => active_http_integration.active,
            'token' => active_http_integration.token,
            'url' => active_http_integration.url,
            'apiUrl' => nil,
            'payloadExample' => payload_example.to_json,
            'payloadAttributeMappings' => [
              {
                'fieldName' => 'TITLE',
                'label' => nil,
                'path' => %w(alert name),
                'type' => 'STRING'
              },
              {
                'fieldName' => 'DESCRIPTION',
                'label' => 'Description',
                'path' => %w(alert desc),
                'type' => 'STRING'
              }
            ],
            'payloadAlertFields' => [
              {
                'label' => 'alert/name',
                'path' => %w(alert name),
                'type' => 'STRING'
              },
              {
                'label' => 'alert/desc',
                'path' => %w(alert desc),
                'type' => 'STRING'
              }
            ]
          },
          {
            'id' => GitlabSchema.id_from_object(inactive_http_integration).to_s,
            'type' => 'HTTP',
            'name' => inactive_http_integration.name,
            'active' => inactive_http_integration.active,
            'token' => inactive_http_integration.token,
            'url' => inactive_http_integration.url,
            'apiUrl' => nil,
            'payloadExample' => "{}",
            'payloadAttributeMappings' => [],
            'payloadAlertFields' => []
          }
        )
      end
    end
  end
end
