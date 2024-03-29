# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseHelper do
  def stub_default_url_options(host: "localhost", protocol: "http", port: nil, script_name: '')
    url_options = { host: host, protocol: protocol, port: port, script_name: script_name }
    allow(Rails.application.routes).to receive(:default_url_options).and_return(url_options)
  end

  describe '#current_license_title' do
    context 'when there is a current license' do
      it 'returns the plan titleized if it has a plan associated to it' do
        custom_plan = 'custom plan'
        license = double('License', plan: custom_plan)
        allow(License).to receive(:current).and_return(license)

        expect(current_license_title).to eq(custom_plan.titleize)
      end

      it 'returns the default title if it does not have a plan associated to it' do
        license = double('License', plan: nil)
        allow(License).to receive(:current).and_return(license)

        expect(current_license_title).to eq('Core')
      end
    end

    context 'when there is NOT a current license' do
      it 'returns the default title' do
        allow(License).to receive(:current).and_return(nil)

        expect(current_license_title).to eq('Core')
      end
    end
  end

  describe '#seats_calculation_message' do
    subject { seats_calculation_message(license) }

    let(:license) { double('License', 'exclude_guests_from_active_count?' => exclude_guests) }

    context 'and guest are excluded from the active count' do
      let(:exclude_guests) { true }

      it 'returns the message' do
        expect(subject).to eq("Users with a Guest role or those who don't belong to a Project or Group will not use a seat from your license.")
      end
    end

    context 'and guest are NOT excluded from the active count' do
      let(:exclude_guests) { false }

      it 'returns nil' do
        expect(subject).to be_blank
      end
    end
  end

  describe '#licensed_users' do
    context 'with a restricted license count' do
      let(:license) do
        double('License', restricted?: { active_user_count: true }, restrictions: { active_user_count: 5 })
      end

      it 'returns a number as string' do
        license = double('License', restricted?: true, restrictions: { active_user_count: 5 })

        expect(licensed_users(license)).to eq '5'
      end
    end

    context 'without a restricted license count' do
      let(:license) { double('License', restricted?: false) }

      it 'returns Unlimited' do
        expect(licensed_users(license)).to eq 'Unlimited'
      end
    end
  end

  describe '#cloud_license_view_data' do
    context 'when there is a current license' do
      it 'returns the data for the view' do
        custom_plan = 'custom plan'
        license = double('License', plan: custom_plan)
        allow(License).to receive(:current).and_return(license)

        expect(cloud_license_view_data).to eq({ has_active_license: 'true' })
      end
    end

    context 'when there is no current license' do
      it 'returns the data for the view' do
        allow(License).to receive(:current).and_return(nil)

        expect(cloud_license_view_data).to eq({ has_active_license: 'false' })
      end
    end
  end
end
