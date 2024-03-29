# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::DestroyService do
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(nil, user) }

  describe '#execute' do
    context 'when destroying an epic' do
      let(:issuable) { create(:epic) }

      it 'records usage ping epic destroy event' do
        expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_destroyed).with(author: user)

        subject.execute(issuable)
      end
    end

    context 'when destroying other issuable type' do
      let(:issuable) { create(:issue) }

      it 'does not track usage ping epic destroy event' do
        expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_destroyed)

        subject.execute(issuable)
      end
    end
  end
end
