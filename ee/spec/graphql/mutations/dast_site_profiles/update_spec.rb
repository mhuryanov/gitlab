# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::DastSiteProfiles::Update do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }

  let(:full_path) { project.full_path }
  let(:new_profile_name) { SecureRandom.hex }
  let(:new_target_url) { generate(:url) }
  let(:new_excluded_urls) { ["#{new_target_url}/signout"] }
  let(:new_request_headers) { "Authorization: Bearer #{SecureRandom.hex}" }

  let(:new_auth) do
    {
      enabled: false,
      url: "#{new_target_url}/login",
      username_field: 'login[username]',
      password_field: 'login[password]',
      username: generate(:email),
      password: SecureRandom.hex
    }
  end

  subject(:mutation) { described_class.new(object: nil, context: { current_user: user }, field: nil) }

  before do
    stub_licensed_features(security_on_demand_scans: true)
  end

  specify { expect(described_class).to require_graphql_authorizations(:create_on_demand_dast_scan) }

  describe '#resolve' do
    subject do
      mutation.resolve(
        full_path: full_path,
        id: dast_site_profile.to_global_id,
        profile_name: new_profile_name,
        target_url: new_target_url,
        excluded_urls: new_excluded_urls,
        request_headers: new_request_headers,
        auth: new_auth
      )
    end

    context 'when on demand scan feature is enabled' do
      context 'when the project does not exist' do
        let(:full_path) { SecureRandom.hex }

        it 'raises an exception' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the user can run a dast scan' do
        before do
          project.add_developer(user)
        end

        it 'calls the dast_site_profile update service' do
          service = double(DastSiteProfiles::UpdateService)
          result = ServiceResponse.error(message: '')

          service_params = {
            id: dast_site_profile.id.to_s,
            name: new_profile_name,
            target_url: new_target_url,
            excluded_urls: new_excluded_urls,
            request_headers: new_request_headers,
            auth_enabled: new_auth[:enabled],
            auth_url: new_auth[:url],
            auth_username_field: new_auth[:username_field],
            auth_password_field: new_auth[:password_field],
            auth_username: new_auth[:username],
            auth_password: new_auth[:password]
          }

          expect(DastSiteProfiles::UpdateService).to receive(:new).and_return(service)
          expect(service).to receive(:execute).with(service_params).and_return(result)

          subject
        end

        it 'updates the dast_site_profile', :aggregate_failures do
          dast_site_profile = subject[:id].find

          expect(dast_site_profile).to have_attributes(
            name: new_profile_name,
            excluded_urls: new_excluded_urls,
            auth_enabled: new_auth[:enabled],
            auth_url: new_auth[:url],
            auth_username_field: new_auth[:username_field],
            auth_password_field: new_auth[:password_field],
            auth_username: new_auth[:username],
            dast_site: have_attributes(url: new_target_url)
          )

          expect(dast_site_profile.secret_variables.map(&:key)).to include(Dast::SiteProfileSecretVariable::REQUEST_HEADERS)
          expect(dast_site_profile.secret_variables.map(&:key)).to include(Dast::SiteProfileSecretVariable::PASSWORD)
        end

        context 'when secret variables already exist' do
          let_it_be(:request_headers_variable) { create(:dast_site_profile_secret_variable, key: Dast::SiteProfileSecretVariable::REQUEST_HEADERS, dast_site_profile: dast_site_profile) }
          let_it_be(:password_variable) { create(:dast_site_profile_secret_variable, key: Dast::SiteProfileSecretVariable::PASSWORD, dast_site_profile: dast_site_profile) }

          context 'when the arguments are omitted' do
            subject do
              mutation.resolve(
                full_path: full_path,
                id: dast_site_profile.to_global_id,
                profile_name: new_profile_name
              )
            end

            it 'does not delete the secret variable' do
              dast_site_profile = subject[:id].find

              expect(dast_site_profile.secret_variables).not_to be_empty
            end
          end

          context 'when the arguments are empty strings' do
            subject do
              mutation.resolve(
                full_path: full_path,
                id: dast_site_profile.to_global_id,
                profile_name: new_profile_name,
                request_headers: '',
                auth: { password: '' }
              )
            end

            it 'deletes secret variables' do
              dast_site_profile = subject[:id].find

              expect(dast_site_profile.secret_variables).to be_empty
            end
          end
        end

        context 'when variable creation fails' do
          it 'returns an error and the dast_site_profile' do
            service = double(Dast::SiteProfileSecretVariables::CreateOrUpdateService)
            result = ServiceResponse.error(payload: create(:dast_site_profile), message: 'Oops')

            allow(Dast::SiteProfileSecretVariables::CreateOrUpdateService).to receive(:new).and_return(service)
            allow(service).to receive(:execute).and_return(result)

            expect(subject).to include(errors: ['Oops'])
          end
        end

        context 'when the feature flag security_dast_site_profiles_additional_fields is disabled' do
          it 'does not update the feature flagged attributes', :aggregate_failures do
            stub_feature_flags(security_dast_site_profiles_additional_fields: false)

            dast_site_profile = subject[:id].find

            expect(dast_site_profile).not_to have_attributes(
              excluded_urls: new_excluded_urls,
              auth_enabled: new_auth[:enabled],
              auth_url: new_auth[:url],
              auth_username_field: new_auth[:username_field],
              auth_password_field: new_auth[:password_field],
              auth_username: new_auth[:username]
            )

            expect(dast_site_profile.secret_variables).to be_empty
          end
        end
      end
    end
  end
end
