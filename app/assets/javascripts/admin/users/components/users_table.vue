<script>
import { GlTable } from '@gitlab/ui';
import { __ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import UserActions from './user_actions.vue';
import UserAvatar from './user_avatar.vue';

const DEFAULT_TH_CLASSES =
  'gl-bg-transparent! gl-border-b-solid! gl-border-b-gray-100! gl-p-5! gl-border-b-1!';
const thWidthClass = (width) => `gl-w-${width}p ${DEFAULT_TH_CLASSES}`;

export default {
  components: {
    GlTable,
    UserAvatar,
    UserActions,
    UserDate,
  },
  props: {
    users: {
      type: Array,
      required: true,
    },
    paths: {
      type: Object,
      required: true,
    },
  },
  fields: [
    {
      key: 'name',
      label: __('Name'),
      thClass: thWidthClass(40),
    },
    {
      key: 'projectsCount',
      label: __('Projects'),
      thClass: thWidthClass(10),
    },
    {
      key: 'createdAt',
      label: __('Created on'),
      thClass: thWidthClass(15),
    },
    {
      key: 'lastActivityOn',
      label: __('Last activity'),
      thClass: thWidthClass(15),
    },
    {
      key: 'settings',
      label: '',
      thClass: thWidthClass(20),
    },
  ],
};
</script>

<template>
  <div>
    <gl-table
      :items="users"
      :fields="$options.fields"
      :empty-text="s__('AdminUsers|No users found')"
      show-empty
      stacked="md"
    >
      <template #cell(name)="{ item: user }">
        <user-avatar :user="user" :admin-user-path="paths.adminUser" />
      </template>

      <template #cell(createdAt)="{ item: { createdAt } }">
        <user-date :date="createdAt" />
      </template>

      <template #cell(lastActivityOn)="{ item: { lastActivityOn } }">
        <user-date :date="lastActivityOn" show-never />
      </template>

      <template #cell(settings)="{ item: user }">
        <user-actions :user="user" :paths="paths" />
      </template>
    </gl-table>
  </div>
</template>
