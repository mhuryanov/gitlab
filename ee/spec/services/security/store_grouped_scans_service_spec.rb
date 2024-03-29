# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreGroupedScansService do
  let_it_be(:report_type) { :dast }
  let_it_be(:build_1) { create(:ee_ci_build, name: 'Report 1') }
  let_it_be(:build_2) { create(:ee_ci_build, name: 'Report 3') }
  let_it_be(:build_3) { create(:ee_ci_build, name: 'Report 2') }
  let_it_be(:artifact_1) { create(:ee_ci_job_artifact, report_type, job: build_1) }
  let_it_be(:artifact_2) { create(:ee_ci_job_artifact, report_type, job: build_2) }
  let_it_be(:artifact_3) { create(:ee_ci_job_artifact, report_type, job: build_3) }

  let(:artifacts) { [artifact_1, artifact_2, artifact_3] }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(artifacts) }

    before do
      allow(described_class).to receive(:new).with(artifacts).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::StoreGroupedScansService`' do
      execute

      expect(described_class).to have_received(:new).with(artifacts)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(artifacts) }
    let(:empty_set) { Set.new }

    subject(:store_scan_group) { service_object.execute }

    context 'when there is a parsing error' do
      let(:expected_error) { Gitlab::Ci::Parsers::ParserError.new('Foo') }

      before do
        allow(Security::StoreScanService).to receive(:execute).and_raise(expected_error)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'does not propagate the error to the caller' do
        expect { store_scan_group }.not_to raise_error
      end

      it 'tracks the error' do
        store_scan_group

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(expected_error)
      end
    end

    context 'when there is no error' do
      before do
        allow(Security::StoreScanService).to receive(:execute).and_return(true)
      end

      context 'when the artifacts are not dependency_scanning' do
        it 'calls the Security::StoreScanService with ordered artifacts' do
          store_scan_group

          expect(Security::StoreScanService).to have_received(:execute).with(artifact_1, empty_set, false).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(artifact_3, empty_set, true).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(artifact_2, empty_set, true).ordered
        end
      end

      context 'when the artifacts are sast' do
        let_it_be(:sast_artifact_1) { create(:ee_ci_job_artifact, :sast, job: create(:ee_ci_build)) }
        let_it_be(:sast_artifact_2) { create(:ee_ci_job_artifact, :sast, job: create(:ee_ci_build)) }
        let_it_be(:sast_artifact_3) { create(:ee_ci_job_artifact, :sast, job: create(:ee_ci_build)) }

        let(:scanner_1) { instance_double(::Gitlab::Ci::Reports::Security::Scanner, external_id: 'unknown') }
        let(:scanner_2) { instance_double(::Gitlab::Ci::Reports::Security::Scanner, external_id: 'bandit') }
        let(:scanner_3) { instance_double(::Gitlab::Ci::Reports::Security::Scanner, external_id: 'semgrep') }
        let(:mock_report_1) { instance_double(::Gitlab::Ci::Reports::Security::Report, primary_scanner: scanner_1) }
        let(:mock_report_2) { instance_double(::Gitlab::Ci::Reports::Security::Report, primary_scanner: scanner_2) }
        let(:mock_report_3) { instance_double(::Gitlab::Ci::Reports::Security::Report, primary_scanner: scanner_3) }
        let(:artifacts) { [sast_artifact_1, sast_artifact_2, sast_artifact_3] }

        before do
          allow(sast_artifact_1).to receive(:security_report).and_return(mock_report_1)
          allow(sast_artifact_2).to receive(:security_report).and_return(mock_report_2)
          allow(sast_artifact_3).to receive(:security_report).and_return(mock_report_3)
        end

        it 'calls the Security::StoreScanService with ordered artifacts' do
          store_scan_group

          expect(Security::StoreScanService).to have_received(:execute).with(sast_artifact_2, empty_set, false).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(sast_artifact_3, empty_set, true).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(sast_artifact_1, empty_set, true).ordered
        end
      end

      context 'when the artifacts are dependency_scanning' do
        let(:report_type) { :dependency_scanning }
        let(:build_4) { create(:ee_ci_build, name: 'Report 0') }
        let(:artifact_4) { create(:ee_ci_job_artifact, report_type, job: build_4) }
        let(:scanner_1) { instance_double(::Gitlab::Ci::Reports::Security::Scanner, external_id: 'this is an unknown id') }
        let(:scanner_2) { instance_double(::Gitlab::Ci::Reports::Security::Scanner, external_id: 'bundler_audit') }
        let(:scanner_3) { instance_double(::Gitlab::Ci::Reports::Security::Scanner, external_id: 'retire.js') }
        let(:mock_report_1) { instance_double(::Gitlab::Ci::Reports::Security::Report, primary_scanner: scanner_1) }
        let(:mock_report_2) { instance_double(::Gitlab::Ci::Reports::Security::Report, primary_scanner: scanner_2) }
        let(:mock_report_3) { instance_double(::Gitlab::Ci::Reports::Security::Report, primary_scanner: scanner_3) }
        let(:artifacts) { [artifact_1, artifact_2, artifact_3, artifact_4] }

        before do
          allow(artifact_1).to receive(:security_report).and_return(mock_report_1)
          allow(artifact_2).to receive(:security_report).and_return(mock_report_2)
          allow(artifact_3).to receive(:security_report).and_return(mock_report_3)
          allow(artifact_4).to receive(:security_report).and_return(mock_report_2)
        end

        it 'calls the Security::StoreScanService with ordered artifacts' do
          store_scan_group

          expect(Security::StoreScanService).to have_received(:execute).with(artifact_4, empty_set, false).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(artifact_2, empty_set, true).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(artifact_3, empty_set, true).ordered
          expect(Security::StoreScanService).to have_received(:execute).with(artifact_1, empty_set, true).ordered
        end
      end
    end
  end
end
