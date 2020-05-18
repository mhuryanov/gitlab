# frozen_string_literal: true

require 'spec_helper'

describe Ci::Build do
  let_it_be(:group) { create(:group_with_plan, plan: :bronze_plan) }
  let(:project) { create(:project, :repository, group: group) }

  let(:pipeline) do
    create(:ci_pipeline, project: project,
                         sha: project.commit.id,
                         ref: project.default_branch,
                         status: 'success')
  end

  let(:job) { create(:ci_build, pipeline: pipeline) }
  let(:artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }

  describe '.license_scan' do
    subject(:build) { described_class.license_scan.first }

    let(:artifact) { build.job_artifacts.first }

    context 'with old license_management artifact' do
      let!(:license_artifact) { create(:ee_ci_job_artifact, :license_management, job: job, project: job.project) }

      it { expect(artifact.file_type).to eq 'license_management' }
    end

    context 'with new license_scanning artifact' do
      let!(:license_artifact) { create(:ee_ci_job_artifact, :license_scanning, job: job, project: job.project) }

      it { expect(artifact.file_type).to eq 'license_scanning' }
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:security_scans) }
  end

  describe '#shared_runners_minutes_limit_enabled?' do
    subject { job.shared_runners_minutes_limit_enabled? }

    shared_examples 'depends on runner presence and type' do
      context 'for shared runner' do
        before do
          job.runner = create(:ci_runner, :instance)
        end

        context 'when project#shared_runners_minutes_limit_enabled? is true' do
          specify do
            expect(job.project).to receive(:shared_runners_minutes_limit_enabled?)
              .and_return(true)

            is_expected.to be_truthy
          end
        end

        context 'when project#shared_runners_minutes_limit_enabled? is false' do
          specify do
            expect(job.project).to receive(:shared_runners_minutes_limit_enabled?)
              .and_return(false)

            is_expected.to be_falsey
          end
        end
      end

      context 'with specific runner' do
        before do
          job.runner = create(:ci_runner, :project)
        end

        it { is_expected.to be_falsey }
      end

      context 'without runner' do
        it { is_expected.to be_falsey }
      end
    end

    it_behaves_like 'depends on runner presence and type'

    context 'and :ci_minutes_track_for_public_projects FF is disabled' do
      before do
        stub_feature_flags(ci_minutes_track_for_public_projects: false)
      end

      it_behaves_like 'depends on runner presence and type'
    end
  end

  context 'updates pipeline minutes' do
    let(:job) { create(:ci_build, :running, pipeline: pipeline) }

    %w(success drop cancel).each do |event|
      it "for event #{event}", :sidekiq_might_not_need_inline do
        expect(UpdateBuildMinutesService)
          .to receive(:new).and_call_original

        job.public_send(event)
      end
    end
  end

  describe '#stick_build_if_status_changed' do
    it 'sticks the build if the status changed' do
      job = create(:ci_build, :pending)

      allow(Gitlab::Database::LoadBalancing).to receive(:enable?)
        .and_return(true)

      expect(Gitlab::Database::LoadBalancing::Sticking).to receive(:stick)
        .with(:build, job.id)

      job.update(status: :running)
    end
  end

  describe '#variables' do
    subject { job.variables }

    context 'when environment specific variable is defined' do
      let(:environment_variable) do
        { key: 'ENV_KEY', value: 'environment', public: false, masked: false }
      end

      before do
        job.update(environment: 'staging')
        create(:environment, name: 'staging', project: job.project)

        variable =
          build(:ci_variable,
                environment_variable.slice(:key, :value)
                  .merge(project: project, environment_scope: 'stag*'))

        variable.save!
      end

      context 'when there is a plan for the group' do
        it 'GITLAB_FEATURES should include the features for that plan' do
          is_expected.to include({ key: 'GITLAB_FEATURES', value: anything, public: true, masked: false })
          features_variable = subject.find { |v| v[:key] == 'GITLAB_FEATURES' }
          expect(features_variable[:value]).to include('multiple_ldap_servers')
        end
      end
    end
  end

  describe '#collect_security_reports!' do
    let(:security_reports) { ::Gitlab::Ci::Reports::Security::Reports.new(pipeline.sha) }

    subject { job.collect_security_reports!(security_reports) }

    before do
      stub_licensed_features(sast: true, dependency_scanning: true, container_scanning: true, dast: true)
    end

    context 'when build has a security report' do
      context 'when there is a sast report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }

        it 'parses blobs and add the results to the report' do
          subject

          expect(security_reports.get_report('sast', artifact).occurrences.size).to eq(33)
        end

        it 'adds the created date to the report' do
          subject

          expect(security_reports.get_report('sast', artifact).created_at.to_s).to eq(artifact.created_at.to_s)
        end
      end

      context 'when there are multiple reports' do
        let!(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }
        let!(:ds_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: job, project: job.project) }
        let!(:cs_artifact) { create(:ee_ci_job_artifact, :container_scanning, job: job, project: job.project) }
        let!(:dast_artifact) { create(:ee_ci_job_artifact, :dast, job: job, project: job.project) }

        it 'parses blobs and adds the results to the reports' do
          subject

          expect(security_reports.get_report('sast', sast_artifact).occurrences.size).to eq(33)
          expect(security_reports.get_report('dependency_scanning', ds_artifact).occurrences.size).to eq(4)
          expect(security_reports.get_report('container_scanning', cs_artifact).occurrences.size).to eq(8)
          expect(security_reports.get_report('dast', dast_artifact).occurrences.size).to eq(20)
        end
      end

      context 'when there is a corrupted sast report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :sast_with_corrupted_data, job: job, project: job.project) }

        it 'stores an error' do
          subject

          expect(security_reports.get_report('sast', artifact)).to be_errored
        end
      end
    end

    context 'when there is unsupported file type' do
      let!(:artifact) { create(:ee_ci_job_artifact, :codequality, job: job, project: job.project) }

      before do
        stub_const("Ci::JobArtifact::SECURITY_REPORT_FILE_TYPES", %w[codequality])
      end

      it 'stores an error' do
        subject

        expect(security_reports.get_report('codequality', artifact)).to be_errored
      end
    end
  end

  describe '#collect_license_scanning_reports!' do
    subject { job.collect_license_scanning_reports!(license_scanning_report) }

    let(:license_scanning_report) { Gitlab::Ci::Reports::LicenseScanning::Report.new }

    before do
      stub_licensed_features(license_scanning: true)
    end

    it { expect(license_scanning_report.licenses.count).to eq(0) }

    context 'when build has a license scanning report' do
      context 'when there is a new type report' do
        before do
          create(:ee_ci_job_artifact, :license_scanning, job: job, project: job.project)
        end

        it 'parses blobs and add the results to the report' do
          expect { subject }.not_to raise_error

          expect(license_scanning_report.licenses.count).to eq(4)
          expect(license_scanning_report.licenses.map(&:name)).to contain_exactly("Apache 2.0", "MIT", "New BSD", "unknown")
          expect(license_scanning_report.licenses.find { |x| x.name == 'MIT' }.dependencies.count).to eq(52)
        end
      end

      context 'when there is an old type report' do
        before do
          create(:ee_ci_job_artifact, :license_management, job: job, project: job.project)
        end

        it 'parses blobs and add the results to the report' do
          expect { subject }.not_to raise_error

          expect(license_scanning_report.licenses.count).to eq(4)
          expect(license_scanning_report.licenses.map(&:name)).to contain_exactly("Apache 2.0", "MIT", "New BSD", "unknown")
          expect(license_scanning_report.licenses.find { |x| x.name == 'MIT' }.dependencies.count).to eq(52)
        end
      end

      context 'when there is a corrupted report' do
        before do
          create(:ee_ci_job_artifact, :license_scan, :with_corrupted_data, job: job, project: job.project)
        end

        it 'raises an error' do
          expect { subject }.to raise_error(Gitlab::Ci::Parsers::LicenseCompliance::LicenseScanning::LicenseScanningParserError)
        end
      end

      context 'when Feature flag is disabled for License Scanning reports parsing' do
        before do
          stub_feature_flags(parse_license_management_reports: false)
          create(:ee_ci_job_artifact, :license_scanning, job: job, project: job.project)
        end

        it 'does NOT parse license scanning report' do
          subject

          expect(license_scanning_report.licenses.count).to eq(0)
        end
      end

      context 'when the license scanning feature is disabled' do
        before do
          stub_licensed_features(license_scanning: false)
          create(:ee_ci_job_artifact, :license_scanning, job: job, project: job.project)
        end

        it 'does NOT parse license scanning report' do
          subject

          expect(license_scanning_report.licenses.count).to eq(0)
        end
      end
    end
  end

  describe '#collect_dependency_list_reports!' do
    let!(:dl_artifact) { create(:ee_ci_job_artifact, :dependency_list, job: job, project: job.project) }
    let(:dependency_list_report) { Gitlab::Ci::Reports::DependencyList::Report.new }

    subject { job.collect_dependency_list_reports!(dependency_list_report) }

    context 'with available licensed feature' do
      before do
        stub_licensed_features(dependency_scanning: true)
      end

      it 'parses blobs and add the results to the report' do
        subject
        blob_path = "/#{project.full_path}/-/blob/#{job.sha}/yarn/yarn.lock"
        mini_portile2 = dependency_list_report.dependencies[0]
        yarn = dependency_list_report.dependencies[20]

        expect(dependency_list_report.dependencies.count).to eq(21)
        expect(mini_portile2[:name]).to eq('mini_portile2')
        expect(yarn[:location][:blob_path]).to eq(blob_path)
      end
    end

    context 'with disabled licensed feature' do
      it 'does NOT parse dependency list report' do
        subject

        expect(dependency_list_report.dependencies).to be_empty
      end
    end
  end

  describe '#collect_licenses_for_dependency_list!' do
    let!(:license_scan_artifact) { create(:ee_ci_job_artifact, :license_scanning, job: job, project: job.project) }
    let(:dependency_list_report) { Gitlab::Ci::Reports::DependencyList::Report.new }
    let(:dependency) { build(:dependency, :nokogiri) }

    subject { job.collect_licenses_for_dependency_list!(dependency_list_report) }

    before do
      dependency_list_report.add_dependency(dependency)
    end

    context 'with available licensed feature' do
      before do
        stub_licensed_features(dependency_scanning: true)
      end

      it 'parses blobs and add found license' do
        subject
        nokogiri = dependency_list_report.dependencies.first

        expect(nokogiri&.dig(:licenses, 0, :name)).to eq('MIT')
      end
    end

    context 'with unavailable licensed feature' do
      it 'does not add licenses' do
        subject
        nokogiri = dependency_list_report.dependencies.first

        expect(nokogiri[:licenses]).to be_empty
      end
    end
  end

  describe '#collect_metrics_reports!' do
    subject { job.collect_metrics_reports!(metrics_report) }

    let(:metrics_report) { Gitlab::Ci::Reports::Metrics::Report.new }

    context 'when there is a metrics report' do
      before do
        create(:ee_ci_job_artifact, :metrics, job: job, project: job.project)
      end

      context 'when license has metrics_reports' do
        before do
          stub_licensed_features(metrics_reports: true)
        end

        it 'parses blobs and add the results to the report' do
          expect { subject }.to change { metrics_report.metrics.count }.from(0).to(2)
        end
      end

      context 'when license does not have metrics_reports' do
        before do
          stub_licensed_features(license_scanning: false)
        end

        it 'does not parse metrics report' do
          subject

          expect(metrics_report.metrics.count).to eq(0)
        end
      end
    end
  end

  describe '#retryable?' do
    subject { build.retryable? }

    let(:pipeline) { merge_request.all_pipelines.last }
    let!(:build) { create(:ci_build, :canceled, pipeline: pipeline) }

    context 'with pipeline for merged results' do
      let(:merge_request) { create(:merge_request, :with_merge_request_pipeline) }

      it { is_expected.to be true }
    end

    context 'with pipeline for merge train' do
      let(:merge_request) { create(:merge_request, :on_train, :with_merge_train_pipeline) }

      it { is_expected.to be false }
    end
  end

  describe ".license_scan" do
    it 'returns only license artifacts' do
      create(:ci_build, job_artifacts: [create(:ci_job_artifact, :zip)])
      build_with_license_scan = create(:ci_build, job_artifacts: [create(:ci_job_artifact, file_type: :license_scanning, file_format: :raw)])

      expect(described_class.license_scan).to contain_exactly(build_with_license_scan)
    end
  end
end
