<script>
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
import getPipelineDetails from 'shared_queries/pipelines/get_pipeline_details.query.graphql';
import { __ } from '~/locale';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { DEFAULT, DRAW_FAILURE, LOAD_FAILURE } from '../../constants';
import { reportToSentry } from '../../utils';
import { listByLayers } from '../parsing_utils';
import { IID_FAILURE, LAYER_VIEW, STAGE_VIEW, VIEW_TYPE_KEY } from './constants';
import PipelineGraph from './graph_component.vue';
import GraphViewSelector from './graph_view_selector.vue';
import {
  getQueryHeaders,
  serializeLoadErrors,
  toggleQueryPollingByVisibility,
  unwrapPipelineData,
} from './utils';

export default {
  name: 'PipelineGraphWrapper',
  components: {
    GlAlert,
    GlLoadingIcon,
    GraphViewSelector,
    LocalStorageSync,
    PipelineGraph,
  },
  mixins: [glFeatureFlagMixin()],
  inject: {
    graphqlResourceEtag: {
      default: '',
    },
    metricsPath: {
      default: '',
    },
    pipelineIid: {
      default: '',
    },
    pipelineProjectPath: {
      default: '',
    },
  },
  data() {
    return {
      alertType: null,
      currentViewType: STAGE_VIEW,
      pipeline: null,
      pipelineLayers: null,
      showAlert: false,
    };
  },
  errorTexts: {
    [DRAW_FAILURE]: __('An error occurred while drawing job relationship links.'),
    [IID_FAILURE]: __(
      'The data in this pipeline is too old to be rendered as a graph. Please check the Jobs tab to access historical data.',
    ),
    [LOAD_FAILURE]: __('We are currently unable to fetch data for this pipeline.'),
    [DEFAULT]: __('An unknown error occurred while loading this graph.'),
  },
  apollo: {
    pipeline: {
      context() {
        return getQueryHeaders(this.graphqlResourceEtag);
      },
      query: getPipelineDetails,
      pollInterval: 10000,
      variables() {
        return {
          projectPath: this.pipelineProjectPath,
          iid: this.pipelineIid,
        };
      },
      skip() {
        return !(this.pipelineProjectPath && this.pipelineIid);
      },
      update(data) {
        /*
          This check prevents the pipeline from being overwritten
          when a poll times out and the data returned is empty.
          This can be removed once the timeout behavior is updated.
          See: https://gitlab.com/gitlab-org/gitlab/-/issues/323213.
        */

        if (!data?.project?.pipeline) {
          return this.pipeline;
        }

        return unwrapPipelineData(this.pipelineProjectPath, data);
      },
      error(err) {
        this.reportFailure({ type: LOAD_FAILURE, skipSentry: true });
        reportToSentry(
          this.$options.name,
          `type: ${LOAD_FAILURE}, info: ${serializeLoadErrors(err)}`,
        );
      },
      result({ error }) {
        /*
          If there is a successful load after a failure, clear
          the failure notification to avoid confusion.
        */
        if (!error && this.alertType === LOAD_FAILURE) {
          this.hideAlert();
        }
      },
    },
  },
  computed: {
    alert() {
      switch (this.alertType) {
        case DRAW_FAILURE:
          return {
            text: this.$options.errorTexts[DRAW_FAILURE],
            variant: 'danger',
          };
        case IID_FAILURE:
          return {
            text: this.$options.errorTexts[IID_FAILURE],
            variant: 'info',
          };
        case LOAD_FAILURE:
          return {
            text: this.$options.errorTexts[LOAD_FAILURE],
            variant: 'danger',
          };
        default:
          return {
            text: this.$options.errorTexts[DEFAULT],
            variant: 'danger',
          };
      }
    },
    configPaths() {
      return {
        graphqlResourceEtag: this.graphqlResourceEtag,
        metricsPath: this.metricsPath,
      };
    },
    showLoadingIcon() {
      /*
        Shows the icon only when the graph is empty, not when it is is
        being refetched, for instance, on action completion
      */
      return this.$apollo.queries.pipeline.loading && !this.pipeline;
    },
    showGraphViewSelector() {
      return Boolean(this.glFeatures.pipelineGraphLayersView && this.pipeline?.usesNeeds);
    },
  },
  mounted() {
    if (!this.pipelineIid) {
      this.reportFailure({ type: IID_FAILURE, skipSentry: true });
    }

    toggleQueryPollingByVisibility(this.$apollo.queries.pipeline);
  },
  errorCaptured(err, _vm, info) {
    reportToSentry(this.$options.name, `error: ${err}, info: ${info}`);
  },
  methods: {
    getPipelineLayers() {
      if (this.currentViewType === LAYER_VIEW && !this.pipelineLayers) {
        this.pipelineLayers = listByLayers(this.pipeline);
      }

      return this.pipelineLayers;
    },
    hideAlert() {
      this.showAlert = false;
      this.alertType = null;
    },
    refreshPipelineGraph() {
      this.$apollo.queries.pipeline.refetch();
    },
    /* eslint-disable @gitlab/require-i18n-strings */
    reportFailure({ type, err = 'No error string passed.', skipSentry = false }) {
      this.showAlert = true;
      this.alertType = type;
      if (!skipSentry) {
        reportToSentry(this.$options.name, `type: ${type}, info: ${err}`);
      }
    },
    /* eslint-enable @gitlab/require-i18n-strings */
    updateViewType(type) {
      this.currentViewType = type;
    },
  },
  viewTypeKey: VIEW_TYPE_KEY,
};
</script>
<template>
  <div>
    <gl-alert v-if="showAlert" :variant="alert.variant" @dismiss="hideAlert">
      {{ alert.text }}
    </gl-alert>
    <local-storage-sync
      :storage-key="$options.viewTypeKey"
      :value="currentViewType"
      @input="updateViewType"
    >
      <graph-view-selector
        v-if="showGraphViewSelector"
        :type="currentViewType"
        @updateViewType="updateViewType"
      />
    </local-storage-sync>
    <gl-loading-icon v-if="showLoadingIcon" class="gl-mx-auto gl-my-4" size="lg" />
    <pipeline-graph
      v-if="pipeline"
      :config-paths="configPaths"
      :pipeline="pipeline"
      :pipeline-layers="getPipelineLayers()"
      :view-type="currentViewType"
      @error="reportFailure"
      @refreshPipelineGraph="refreshPipelineGraph"
    />
  </div>
</template>
