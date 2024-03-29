# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::DastSiteProfilesController, type: :request do
  include GraphqlHelpers

  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:dast_site_profile) { create(:dast_site_profile, project: project) }

  def with_feature_available
    stub_licensed_features(security_on_demand_scans: true)
  end

  def with_user_authorized
    project.add_developer(user)
    login_as(user)
  end

  shared_examples 'a GET request' do
    include_context '"Security & Compliance" permissions' do
      let(:valid_request) { get path }

      before_request do
        with_feature_available
        with_user_authorized
      end
    end

    context 'feature available' do
      before do
        with_feature_available
      end

      context 'user authorized' do
        before do
          with_user_authorized
        end

        it 'can access page' do
          get path

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'user not authorized' do
        before do
          project.add_guest(user)

          login_as(user)
        end

        it 'sees a 404 error' do
          get path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'feature not available' do
      before do
        with_user_authorized
      end

      context 'license doesnt\'t support the feature' do
        it 'sees a 404 error' do
          stub_licensed_features(security_on_demand_scans: false)
          get path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET #new' do
    it_behaves_like 'a GET request' do
      let(:path) { new_project_security_configuration_dast_scans_dast_site_profile_path(project) }
    end
  end

  describe 'GET #edit' do
    let(:edit_path) { edit_project_security_configuration_dast_scans_dast_site_profile_path(project, dast_site_profile) }

    it_behaves_like 'a GET request' do
      let(:path) { edit_path }
    end

    context 'feature available and user authorized' do
      before do
        with_feature_available
        with_user_authorized
      end

      context 'record exists' do
        before do
          create(:dast_site_profile_secret_variable, dast_site_profile: dast_site_profile, key: Dast::SiteProfileSecretVariable::PASSWORD)
          create(:dast_site_profile_secret_variable, dast_site_profile: dast_site_profile, key: Dast::SiteProfileSecretVariable::REQUEST_HEADERS)
        end

        it 'includes a serialized dast_profile in the response body' do
          get edit_path

          json_data = {
            id: global_id_of(dast_site_profile),
            name: dast_site_profile.name,
            targetUrl:  dast_site_profile.dast_site.url,
            excludedUrls:  dast_site_profile.excluded_urls,
            requestHeaders:  Dast::SiteProfilePresenter::REDACTED_REQUEST_HEADERS,
            auth: {
              enabled: dast_site_profile.auth_enabled,
              url: dast_site_profile.auth_url,
              username: dast_site_profile.auth_username,
              usernameField: dast_site_profile.auth_username_field,
              password: Dast::SiteProfilePresenter::REDACTED_PASSWORD,
              passwordField: dast_site_profile.auth_password_field
            },
            referencedInSecurityPolicies: dast_site_profile.referenced_in_security_policies
          }.to_json

          form = Nokogiri::HTML.parse(response.body).at_css('div.js-dast-site-profile-form')

          expect(form.attributes['data-site-profile'].value).to include(json_data)
        end
      end

      context 'record does not exist' do
        let(:dast_site_profile) { 0 }

        it 'sees a 404 error' do
          get edit_path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
