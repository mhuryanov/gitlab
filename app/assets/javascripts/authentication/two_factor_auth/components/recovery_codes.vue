<script>
import { GlSprintf, GlButton, GlAlert } from '@gitlab/ui';
import Mousetrap from 'mousetrap';
import { __ } from '~/locale';
import Tracking from '~/tracking';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import {
  COPY_BUTTON_ACTION,
  DOWNLOAD_BUTTON_ACTION,
  PRINT_BUTTON_ACTION,
  TRACKING_LABEL_PREFIX,
  RECOVERY_CODE_DOWNLOAD_FILENAME,
  COPY_KEYBOARD_SHORTCUT,
} from '../constants';

export const i18n = {
  pageTitle: __('Two-factor Authentication Recovery codes'),
  alertTitle: __('Please copy, download, or print your recovery codes before proceeding.'),
  pageDescription: __(
    'Should you ever lose your phone or access to your one time password secret, each of these recovery codes can be used one time each to regain access to your account. Please save them in a safe place, or you %{boldStart}will%{boldEnd} lose access to your account.',
  ),
  copyButton: __('Copy codes'),
  downloadButton: __('Download codes'),
  printButton: __('Print codes'),
  proceedButton: __('Proceed'),
};

export default {
  name: 'RecoveryCodes',
  copyButtonAction: COPY_BUTTON_ACTION,
  downloadButtonAction: DOWNLOAD_BUTTON_ACTION,
  printButtonAction: PRINT_BUTTON_ACTION,
  trackingLabelPrefix: TRACKING_LABEL_PREFIX,
  recoveryCodeDownloadFilename: RECOVERY_CODE_DOWNLOAD_FILENAME,
  i18n,
  mousetrap: null,
  components: { GlSprintf, GlButton, GlAlert, ClipboardButton },
  mixins: [Tracking.mixin()],
  props: {
    codes: {
      type: Array,
      required: true,
    },
    profileAccountPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      proceedButtonDisabled: true,
    };
  },
  computed: {
    codesAsString() {
      return this.codes.join('\n');
    },
    codeDownloadUrl() {
      return `data:text/plain;charset=utf-8,${encodeURIComponent(this.codesAsString)}`;
    },
  },
  created() {
    this.$options.mousetrap = new Mousetrap();

    this.$options.mousetrap.bind(COPY_KEYBOARD_SHORTCUT, this.handleKeyboardCopy);
  },
  beforeDestroy() {
    if (!this.$options.mousetrap) {
      return;
    }

    this.$options.mousetrap.unbind(COPY_KEYBOARD_SHORTCUT);
  },
  methods: {
    handleButtonClick(action) {
      this.proceedButtonDisabled = false;

      if (action === this.$options.printButtonAction) {
        window.print();
      }

      this.track('click_button', { label: `${this.$options.trackingLabelPrefix}${action}_button` });
    },
    handleKeyboardCopy() {
      if (!window.getSelection) {
        return;
      }

      const copiedText = window.getSelection().toString();

      if (copiedText.includes(this.codesAsString)) {
        this.proceedButtonDisabled = false;
        this.track('copy_keyboard_shortcut', {
          label: `${this.$options.trackingLabelPrefix}manual_copy`,
        });
      }
    },
  },
};
</script>

<template>
  <div>
    <h3 class="page-title">
      {{ $options.i18n.pageTitle }}
    </h3>
    <hr />
    <gl-alert variant="info" :dismissible="false">
      {{ $options.i18n.alertTitle }}
    </gl-alert>
    <p class="gl-mt-5">
      <gl-sprintf :message="$options.i18n.pageDescription">
        <template #bold="{ content }"
          ><strong>{{ content }}</strong></template
        >
      </gl-sprintf>
    </p>

    <div
      class="codes-to-print gl-my-5 gl-p-5 gl-border-solid gl-border-1 gl-border-gray-100 gl-rounded-base"
      data-testid="recovery-codes"
      data-qa-selector="codes_content"
    >
      <ul class="gl-m-0 gl-pl-5">
        <li v-for="(code, index) in codes" :key="index">
          <span class="gl-font-monospace" data-qa-selector="code_content">{{ code }}</span>
        </li>
      </ul>
    </div>
    <div class="gl-my-n2 gl-mx-n2 gl-display-flex gl-flex-wrap">
      <div class="gl-p-2">
        <clipboard-button
          :title="$options.i18n.copyButton"
          :text="codesAsString"
          data-qa-selector="copy_button"
          @click="handleButtonClick($options.copyButtonAction)"
        >
          {{ $options.i18n.copyButton }}
        </clipboard-button>
      </div>
      <div class="gl-p-2">
        <gl-button
          :href="codeDownloadUrl"
          :title="$options.i18n.downloadButton"
          icon="download"
          :download="$options.recoveryCodeDownloadFilename"
          @click="handleButtonClick($options.downloadButtonAction)"
        >
          {{ $options.i18n.downloadButton }}
        </gl-button>
      </div>
      <div class="gl-p-2">
        <gl-button
          :title="$options.i18n.printButton"
          @click="handleButtonClick($options.printButtonAction)"
        >
          {{ $options.i18n.printButton }}
        </gl-button>
      </div>
      <div class="gl-p-2">
        <gl-button
          :href="profileAccountPath"
          :disabled="proceedButtonDisabled"
          :title="$options.i18n.proceedButton"
          variant="confirm"
          data-qa-selector="proceed_button"
          data-track-event="click_button"
          :data-track-label="`${$options.trackingLabelPrefix}proceed_button`"
          >{{ $options.i18n.proceedButton }}</gl-button
        >
      </div>
    </div>
  </div>
</template>
