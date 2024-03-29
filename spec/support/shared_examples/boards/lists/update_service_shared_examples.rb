# frozen_string_literal: true

RSpec.shared_examples 'moving list' do
  context 'when user can admin list' do
    it 'calls Lists::MoveService to update list position' do
      board.resource_parent.add_developer(user)

      expect_next_instance_of(Boards::Lists::MoveService, board.resource_parent, user, params) do |move_service|
        expect(move_service).to receive(:execute).with(list).and_call_original
      end

      service.execute(list)
    end
  end

  context 'when user cannot admin list' do
    it 'does not call Lists::MoveService to update list position' do
      expect(Boards::Lists::MoveService).not_to receive(:new)

      service.execute(list)
    end
  end
end

RSpec.shared_examples 'updating list preferences' do
  context 'when user can read list' do
    it 'updates list preference for user' do
      board.resource_parent.add_guest(user)

      service.execute(list)

      expect(list.preferences_for(user).collapsed).to eq(true)
    end
  end

  context 'when user cannot read list' do
    it 'does not update list preference for user' do
      service.execute(list)

      expect(list.preferences_for(user).collapsed).to be_falsy
    end
  end
end
