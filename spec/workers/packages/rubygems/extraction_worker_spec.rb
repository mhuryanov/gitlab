# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Rubygems::ExtractionWorker, type: :worker do
  describe '#perform' do
    let_it_be(:package) { create(:rubygems_package) }

    let(:package_file) { package.package_files.first }
    let(:package_file_id) { package_file.id }
    let(:package_name) { 'TempProject.TempPackage' }
    let(:package_version) { '1.0.0' }
    let(:job_args) { package_file_id }

    subject { described_class.new.perform(*job_args) }

    include_examples 'an idempotent worker' do
      it 'processes the gem', :aggregate_failures do
        expect { subject }
          .to change { Packages::Package.count }.by(0)
          .and change { Packages::PackageFile.count }.by(2)

        expect(Packages::Package.last.id).to be(package.id)
        expect(package.name).not_to be(package_name)
      end
    end

    it 'handles a processing failure', :aggregate_failures do
      expect(::Packages::Rubygems::ProcessGemService).to receive(:new)
        .and_raise(::Packages::Rubygems::ProcessGemService::ExtractionError)

      expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
        instance_of(::Packages::Rubygems::ProcessGemService::ExtractionError),
        project_id: package.project_id
      )

      expect { subject }
        .to change { Packages::Package.count }.by(-1)
        .and change { Packages::PackageFile.count }.by(-2)
    end

    context 'returns when there is no package file' do
      let(:package_file_id) { 999999 }

      it 'returns without action' do
        expect(::Packages::Rubygems::ProcessGemService).not_to receive(:new)

        expect { subject }
          .to change { Packages::Package.count }.by(0)
          .and change { Packages::PackageFile.count }.by(0)
      end
    end
  end
end
