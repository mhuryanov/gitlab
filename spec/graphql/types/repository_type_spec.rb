# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Repository'] do
  specify { expect(described_class.graphql_name).to eq('Repository') }

  specify { expect(described_class).to require_graphql_authorizations(:download_code) }

  specify { expect(described_class).to have_graphql_field(:root_ref) }

  specify { expect(described_class).to have_graphql_field(:tree) }

  specify { expect(described_class).to have_graphql_field(:exists, calls_gitaly?: true, complexity: 2) }

  specify { expect(described_class).to have_graphql_field(:blobs) }

  specify { expect(described_class).to have_graphql_field(:branch_names, calls_gitaly?: true, complexity: 170) }
end
