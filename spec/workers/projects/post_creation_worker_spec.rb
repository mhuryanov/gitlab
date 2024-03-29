# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::PostCreationWorker do
  let_it_be(:user) { create :user }

  let(:worker) { described_class.new }
  let(:project) { create(:project) }

  subject { described_class.new.perform(project.id) }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [project.id] }

    describe 'Prometheus service' do
      context 'project is nil' do
        let(:job_args) { [nil] }

        it 'does not create prometheus service' do
          expect { subject }.not_to change { Service.count }
        end
      end

      context 'when project has access to shared service' do
        context 'Prometheus application is shared via group cluster' do
          let(:project) { create(:project, group: group) }
          let(:cluster) { create(:cluster, :group, groups: [group]) }
          let(:group) do
            create(:group).tap do |group|
              group.add_owner(user)
            end
          end

          before do
            create(:clusters_applications_prometheus, :installed, cluster: cluster)
          end

          it 'creates PrometheusService record', :aggregate_failures do
            subject

            service = project.prometheus_service
            expect(service.active).to be true
            expect(service.manual_configuration?).to be false
            expect(service.persisted?).to be true
          end
        end

        context 'Prometheus application is shared via instance cluster' do
          let(:cluster) { create(:cluster, :instance) }

          before do
            create(:clusters_applications_prometheus, :installed, cluster: cluster)
          end

          it 'creates PrometheusService record', :aggregate_failures do
            subject

            service = project.prometheus_service
            expect(service.active).to be true
            expect(service.manual_configuration?).to be false
            expect(service.persisted?).to be true
          end

          it 'cleans invalid record and logs warning', :aggregate_failures do
            invalid_service_record = build(:prometheus_service, properties: { api_url: nil, manual_configuration: true }.to_json)
            allow(PrometheusService).to receive(:new).and_return(invalid_service_record)

            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(an_instance_of(ActiveRecord::RecordInvalid), include(extra: { project_id: a_kind_of(Integer) })).twice
            subject

            expect(project.prometheus_service).to be_nil
          end
        end

        context 'shared Prometheus application is not available' do
          it 'does not persist PrometheusService record', :aggregate_failures do
            subject

            expect(project.prometheus_service).to be_nil
          end
        end
      end
    end
  end
end
