<script>
import { GlCard } from '@gitlab/ui';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { __, s__ } from '~/locale';
import GeoNodeProgressBar from '../geo_node_progress_bar.vue';

export default {
  name: 'GeoNodePrimaryOtherInfo',
  i18n: {
    otherInformation: __('Other information'),
    replicationSlotWAL: s__('Geo|Replication slot WAL'),
  },
  components: {
    GlCard,
    GeoNodeProgressBar,
  },
  props: {
    node: {
      type: Object,
      required: true,
    },
  },
  computed: {
    replicationSlotWAL() {
      return numberToHumanSize(this.node.replicationSlotsMaxRetainedWalBytes);
    },
    replicationSlots() {
      return {
        title: s__('Geo|Replication slots'),
        values: {
          total: this.node.replicationSlotsCount || 0,
          success: this.node.replicationSlotsUsedCount || 0,
        },
      };
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <h5 class="gl-my-0">{{ $options.i18n.otherInformation }}</h5>
    </template>
    <div class="gl-mb-5">
      <span>{{ replicationSlots.title }}</span>
      <geo-node-progress-bar
        class="gl-mt-3"
        :title="replicationSlots.title"
        :values="replicationSlots.values"
      />
    </div>
    <div
      v-if="node.replicationSlotsMaxRetainedWalBytes"
      class="gl-display-flex gl-flex-direction-column gl-mb-5"
    >
      <span>{{ $options.i18n.replicationSlotWAL }}</span>
      <span class="gl-font-weight-bold gl-mt-2" data-testid="replication-slot-wal">{{
        replicationSlotWAL
      }}</span>
    </div>
  </gl-card>
</template>
