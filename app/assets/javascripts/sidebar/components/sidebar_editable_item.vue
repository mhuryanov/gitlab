<script>
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  components: { GlButton, GlLoadingIcon },
  inject: {
    canUpdate: {},
    isClassicSidebar: {
      default: false,
    },
  },
  props: {
    title: {
      type: String,
      required: false,
      default: '',
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    initialLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
    tracking: {
      type: Object,
      required: false,
      default: () => ({
        event: null,
        label: null,
        property: null,
      }),
    },
  },
  data() {
    return {
      edit: false,
    };
  },
  computed: {
    editButtonText() {
      return this.isDirty ? __('Apply') : __('Edit');
    },
  },
  destroyed() {
    window.removeEventListener('click', this.collapseWhenOffClick);
    window.removeEventListener('keyup', this.collapseOnEscape);
  },
  methods: {
    collapseWhenOffClick({ target }) {
      if (!this.$el.contains(target)) {
        this.collapse();
      }
    },
    collapseOnEscape({ key }) {
      if (key === 'Escape') {
        this.collapse();
      }
    },
    expand() {
      if (this.edit) {
        return;
      }

      this.edit = true;
      this.$emit('open');
      window.addEventListener('click', this.collapseWhenOffClick);
      window.addEventListener('keyup', this.collapseOnEscape);
    },
    collapse({ emitEvent = true } = {}) {
      if (!this.edit) {
        return;
      }

      this.edit = false;
      if (emitEvent) {
        this.$emit('close');
      }
      window.removeEventListener('click', this.collapseWhenOffClick);
      window.removeEventListener('keyup', this.collapseOnEscape);
    },
    toggle({ emitEvent = true } = {}) {
      if (this.edit) {
        this.collapse({ emitEvent });
      } else {
        this.expand();
      }
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-display-flex gl-align-items-center" @click.self="collapse">
      <span class="hide-collapsed" data-testid="title" @click="collapse">{{ title }}</span>
      <gl-loading-icon v-if="loading || initialLoading" inline class="gl-ml-2 hide-collapsed" />
      <gl-loading-icon
        v-if="loading && isClassicSidebar"
        inline
        class="gl-mx-auto gl-my-0 hide-expanded"
      />
      <gl-button
        v-if="canUpdate && !initialLoading"
        variant="link"
        class="gl-text-gray-900! gl-hover-text-blue-800! gl-ml-auto hide-collapsed"
        data-testid="edit-button"
        :data-track-event="tracking.event"
        :data-track-label="tracking.label"
        :data-track-property="tracking.property"
        data-qa-selector="edit_link"
        @keyup.esc="toggle"
        @click="toggle"
      >
        {{ editButtonText }}
      </gl-button>
    </div>
    <template v-if="!initialLoading">
      <div v-show="!edit" data-testid="collapsed-content">
        <slot name="collapsed">{{ __('None') }}</slot>
      </div>
      <div v-show="edit" data-testid="expanded-content" :class="{ 'gl-mt-3': !isClassicSidebar }">
        <slot :edit="edit"></slot>
      </div>
    </template>
  </div>
</template>
