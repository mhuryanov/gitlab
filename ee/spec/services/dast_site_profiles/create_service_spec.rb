# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DastSiteProfiles::CreateService do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, creator: user) }
  let_it_be(:name) { FFaker::Company.catch_phrase }
  let_it_be(:target_url) { generate(:url) }
  let_it_be(:excluded_urls) { ["#{target_url}/signout"] }
  let_it_be(:request_headers) { "Authorization: Bearer #{SecureRandom.hex}" }

  let(:default_params) do
    {
      name: name,
      target_url: target_url,
      excluded_urls: excluded_urls,
      request_headers: request_headers,
      auth_enabled: true,
      auth_url: "#{target_url}/login",
      auth_username_field: 'session[username]',
      auth_password_field: 'session[password]',
      auth_username: generate(:email),
      auth_password: SecureRandom.hex
    }
  end

  let(:params) { default_params }

  before do
    stub_licensed_features(security_on_demand_scans: true)
  end

  describe '#execute' do
    subject { described_class.new(project, user).execute(**params) }

    let(:status) { subject.status }
    let(:message) { subject.message }
    let(:errors) { subject.errors }
    let(:payload) { subject.payload }

    context 'when a user does not have access to the project' do
      it 'returns an error status' do
        expect(status).to eq(:error)
      end

      it 'populates message' do
        expect(message).to eq('Insufficient permissions')
      end
    end

    context 'when the user can run a dast scan' do
      before do
        project.add_developer(user)
      end

      it 'returns a success status' do
        expect(status).to eq(:success)
      end

      it 'creates a dast_site_profile' do
        expect { subject }.to change(DastSiteProfile, :count).by(1)
      end

      it 'creates a dast_site' do
        expect { subject }.to change(DastSite, :count).by(1)
      end

      it 'sets attributes correctly' do
        expect(payload).to have_attributes(
          params.except(:request_headers, :auth_password, :target_url).merge(dast_site: have_attributes(url: target_url))
        )
      end

      it 'returns a dast_site_profile payload' do
        expect(payload).to be_a(DastSiteProfile)
      end

      context 'when the dast_site already exists' do
        before do
          create(:dast_site, project: project, url: target_url)
        end

        it 'returns a success status' do
          expect(status).to eq(:success)
        end

        it 'does not create a new dast_site' do
          expect { subject }.not_to change(DastSite, :count)
        end
      end

      context 'when the target url is localhost' do
        let(:target_url) { 'http://localhost:3000/hello-world' }

        it 'returns an error status' do
          expect(status).to eq(:error)
        end

        it 'populates errors' do
          expect(errors).to include('Url is blocked: Requests to localhost are not allowed')
        end
      end

      context 'when excluded_urls is nil' do
        let(:excluded_urls) { nil }

        it 'defaults to an empty array' do
          expect(payload.excluded_urls).to be_empty
        end
      end

      context 'when excluded_urls is not supplied' do
        let(:params) { default_params.except(:excluded_urls) }

        it 'defaults to an empty array' do
          expect(payload.excluded_urls).to be_empty
        end
      end

      context 'when auth values are not supplied' do
        let(:params) { default_params.except(:auth_enabled, :auth_url, :auth_username_field, :auth_password_field, :auth_password_field, :auth_username) }

        it 'uses sensible defaults' do
          expect(payload).to have_attributes(
            auth_enabled: false,
            auth_url: nil,
            auth_username_field: nil,
            auth_password_field: nil,
            auth_username: nil
          )
        end
      end

      shared_examples 'it handles secret variable creation' do
        it 'correctly sets the value' do
          variable = Dast::SiteProfileSecretVariable.find_by(key: key, dast_site_profile: payload)

          expect(Base64.strict_decode64(variable.value)).to eq(raw_value)
        end

        context 'when the feature flag is disabled' do
          it 'does not create a secret variable' do
            stub_feature_flags(security_dast_site_profiles_additional_fields: false)

            expect { subject }.not_to change { Dast::SiteProfileSecretVariable.count }
          end
        end
      end

      shared_examples 'it handles secret variable creation failure' do
        before do
          allow_next_instance_of(Dast::SiteProfileSecretVariables::CreateOrUpdateService) do |service|
            response = ServiceResponse.error(message: 'Something went wrong')

            allow(service).to receive(:execute).and_return(response)
          end
        end

        it 'returns an error response', :aggregate_failures do
          expect(status).to eq(:error)
          expect(message).to include('Something went wrong')
        end
      end

      context 'when request_headers are supplied' do
        let(:key) { 'DAST_REQUEST_HEADERS_BASE64' }
        let(:raw_value) { params[:request_headers] }

        it_behaves_like 'it handles secret variable creation'
        it_behaves_like 'it handles secret variable creation failure'
      end

      context 'when auth_password is supplied' do
        let(:key) { 'DAST_PASSWORD_BASE64' }
        let(:raw_value) { params[:auth_password] }

        it_behaves_like 'it handles secret variable creation'
        it_behaves_like 'it handles secret variable creation failure'
      end

      context 'when on demand scan licensed feature is not available' do
        before do
          stub_licensed_features(security_on_demand_scans: false)
        end

        it 'returns an error status' do
          expect(status).to eq(:error)
        end

        it 'populates message' do
          expect(message).to eq('Insufficient permissions')
        end
      end
    end
  end
end
