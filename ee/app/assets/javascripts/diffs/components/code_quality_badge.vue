<script>
import { GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  components: {
    GlBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    badgeTitle: __('Code Quality'),
    badgeTooltip: __(
      'The merge request has made changes to this file that affect the number of code quality violations in it.',
    ),
  },
};
</script>

<template>
  <gl-badge
    v-gl-tooltip
    :title="$options.i18n.badgeTooltip"
    icon="information"
    class="gl-display-inline-block"
  >
    {{ $options.i18n.badgeTitle }}
  </gl-badge>
</template>
