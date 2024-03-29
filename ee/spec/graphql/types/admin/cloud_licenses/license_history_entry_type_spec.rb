# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['LicenseHistoryEntry'], :enable_admin_mode do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:licensee) do
    {
      'Name' => 'User Example',
      'Email' => 'user@example.com',
      'Company' => 'Example Inc.'
    }
  end

  let_it_be(:license) { create_current_license(licensee: licensee, type: License::CLOUD_LICENSE_TYPE) }

  def query(field_name)
    %(
      {
        licenseHistoryEntries {
          nodes {
            #{field_name}
          }
        }
      }
    )
  end

  def query_field(field_name)
    GitlabSchema.execute(query(field_name), context: { current_user: admin }).as_json
  end

  before do
    stub_application_setting(cloud_license_enabled: true)
  end

  it { expect(described_class.graphql_name).to eq('LicenseHistoryEntry') }

  include_examples 'license type fields', ['data', 'licenseHistoryEntries', 'nodes', -1]
end
