<script>
import { GlCard, GlIcon, GlPopover, GlLink } from '@gitlab/ui';
import { mapGetters } from 'vuex';
import { HELP_INFO_URL } from 'ee/geo_nodes_beta/constants';
import { s__, __ } from '~/locale';
import GeoNodeProgressBar from '../geo_node_progress_bar.vue';

export default {
  name: 'GeoNodeVerificationInfo',
  i18n: {
    verificationInfo: s__('Geo|Verificaton information'),
    replicationHelpText: s__(
      'Geo|Replicated data is verified with the secondary node(s) using checksums.',
    ),
    learnMore: __('Learn more'),
    progressBarTitle: s__('Geo|%{title} checksum progress'),
  },
  components: {
    GlCard,
    GlIcon,
    GlPopover,
    GlLink,
    GeoNodeProgressBar,
  },
  props: {
    node: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ...mapGetters(['verificationInfo']),
    verificationInfoBars() {
      return this.verificationInfo(this.node.id);
    },
  },
  HELP_INFO_URL,
};
</script>

<template>
  <gl-card header-class="gl-display-flex gl-align-items-center">
    <template #header>
      <h5 class="gl-my-0">{{ $options.i18n.verificationInfo }}</h5>
      <gl-icon
        ref="verificationInfo"
        name="question"
        class="gl-text-blue-500 gl-cursor-pointer gl-ml-2"
      />
      <gl-popover :target="() => $refs.verificationInfo.$el" placement="top" triggers="hover focus">
        <p class="gl-font-base">
          {{ $options.i18n.replicationHelpText }}
        </p>
        <gl-link :href="$options.HELP_INFO_URL" target="_blank">{{
          $options.i18n.learnMore
        }}</gl-link>
      </gl-popover>
    </template>
    <div v-for="bar in verificationInfoBars" :key="bar.title" class="gl-mb-5">
      <span data-testid="verification-bar-title">{{
        sprintf($options.i18n.progressBarTitle, { title: bar.title })
      }}</span>
      <geo-node-progress-bar
        class="gl-mt-3"
        :title="sprintf($options.i18n.progressBarTitle, { title: bar.title })"
        :values="bar.values"
      />
    </div>
  </gl-card>
</template>
