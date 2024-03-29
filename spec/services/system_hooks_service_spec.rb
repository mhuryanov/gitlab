# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemHooksService do
  let(:user)           { create(:user) }
  let(:project)        { create(:project) }
  let(:project_member) { create(:project_member) }
  let(:key)            { create(:key, user: user) }
  let(:deploy_key)     { create(:key) }
  let(:group)          { create(:group) }
  let(:group_member)   { create(:group_member) }

  context 'event data' do
    it { expect(event_data(user, :create)).to include(:event_name, :name, :created_at, :updated_at, :email, :user_id, :username) }
    it { expect(event_data(user, :destroy)).to include(:event_name, :name, :created_at, :updated_at, :email, :user_id, :username) }
    it { expect(event_data(project, :create)).to include(:event_name, :name, :created_at, :updated_at, :path, :project_id, :owner_name, :owner_email, :project_visibility) }
    it { expect(event_data(project, :update)).to include(:event_name, :name, :created_at, :updated_at, :path, :project_id, :owner_name, :owner_email, :project_visibility) }
    it { expect(event_data(project, :destroy)).to include(:event_name, :name, :created_at, :updated_at, :path, :project_id, :owner_name, :owner_email, :project_visibility) }
    it { expect(event_data(project_member, :create)).to include(:event_name, :created_at, :updated_at, :project_name, :project_path, :project_path_with_namespace, :project_id, :user_name, :user_username, :user_email, :user_id, :access_level, :project_visibility) }
    it { expect(event_data(project_member, :destroy)).to include(:event_name, :created_at, :updated_at, :project_name, :project_path, :project_path_with_namespace, :project_id, :user_name, :user_username, :user_email, :user_id, :access_level, :project_visibility) }
    it { expect(event_data(project_member, :update)).to include(:event_name, :created_at, :updated_at, :project_name, :project_path, :project_path_with_namespace, :project_id, :user_name, :user_username, :user_email, :user_id, :access_level, :project_visibility) }
    it { expect(event_data(key, :create)).to include(:username, :key, :id) }
    it { expect(event_data(key, :destroy)).to include(:username, :key, :id) }
    it { expect(event_data(deploy_key, :create)).to include(:key, :id) }
    it { expect(event_data(deploy_key, :destroy)).to include(:key, :id) }

    it do
      project.old_path_with_namespace = 'renamed_from_path'
      expect(event_data(project, :rename)).to include(
        :event_name, :name, :created_at, :updated_at, :path, :project_id,
        :owner_name, :owner_email, :project_visibility,
        :old_path_with_namespace
      )
    end

    it do
      project.old_path_with_namespace = 'transferred_from_path'
      expect(event_data(project, :transfer)).to include(
        :event_name, :name, :created_at, :updated_at, :path, :project_id,
        :owner_name, :owner_email, :project_visibility,
        :old_path_with_namespace
      )
    end

    it do
      expect(event_data(group, :create)).to include(
        :event_name, :name, :created_at, :updated_at, :path, :group_id
      )
    end

    it do
      expect(event_data(group, :destroy)).to include(
        :event_name, :name, :created_at, :updated_at, :path, :group_id
      )
    end

    it do
      expect(event_data(group_member, :create)).to include(
        :event_name, :created_at, :updated_at, :group_name, :group_path,
        :group_id, :user_id, :user_username, :user_name, :user_email, :group_access
      )
    end

    it do
      expect(event_data(group_member, :destroy)).to include(
        :event_name, :created_at, :updated_at, :group_name, :group_path,
        :group_id, :user_id, :user_username, :user_name, :user_email, :group_access
      )
    end

    it do
      expect(event_data(group_member, :update)).to include(
        :event_name, :created_at, :updated_at, :group_name, :group_path,
        :group_id, :user_id, :user_username, :user_name, :user_email, :group_access
      )
    end

    it 'includes the correct project visibility level' do
      data = event_data(project, :create)

      expect(data[:project_visibility]).to eq('private')
    end

    it 'handles nil datetime columns' do
      user.update!(created_at: nil, updated_at: nil)
      data = event_data(user, :destroy)

      expect(data[:created_at]).to be(nil)
      expect(data[:updated_at]).to be(nil)
    end

    context 'group_rename' do
      it 'contains old and new path' do
        allow(group).to receive(:path_before_last_save).and_return('old-path')

        data = event_data(group, :rename)

        expect(data).to include(:event_name, :name, :created_at, :updated_at, :full_path, :path, :group_id, :old_path, :old_full_path)
        expect(data[:path]).to eq(group.path)
        expect(data[:full_path]).to eq(group.path)
        expect(data[:old_path]).to eq(group.path_before_last_save)
        expect(data[:old_full_path]).to eq(group.path_before_last_save)
      end

      it 'contains old and new full_path for subgroup' do
        subgroup = create(:group, parent: group)
        allow(subgroup).to receive(:path_before_last_save).and_return('old-path')

        data = event_data(subgroup, :rename)

        expect(data[:full_path]).to eq(subgroup.full_path)
        expect(data[:old_path]).to eq('old-path')
      end
    end
  end

  context 'event names' do
    it { expect(event_name(project, :create)).to eq "project_create" }
    it { expect(event_name(project, :destroy)).to eq "project_destroy" }
    it { expect(event_name(project, :rename)).to eq "project_rename" }
    it { expect(event_name(project, :transfer)).to eq "project_transfer" }
    it { expect(event_name(project, :update)).to eq "project_update" }
    it { expect(event_name(key, :create)).to eq 'key_create' }
    it { expect(event_name(key, :destroy)).to eq 'key_destroy' }
  end

  def event_data(*args)
    SystemHooksService.new.send :build_event_data, *args
  end

  def event_name(*args)
    SystemHooksService.new.send :build_event_name, *args
  end
end
