<script>
import { reportToSentry } from '../../utils';
import LinkedGraphWrapper from '../graph_shared/linked_graph_wrapper.vue';
import LinksLayer from '../graph_shared/links_layer.vue';
import { DOWNSTREAM, MAIN, UPSTREAM, ONE_COL_WIDTH, STAGE_VIEW } from './constants';
import LinkedPipelinesColumn from './linked_pipelines_column.vue';
import StageColumnComponent from './stage_column_component.vue';
import { validateConfigPaths } from './utils';

export default {
  name: 'PipelineGraph',
  components: {
    LinksLayer,
    LinkedGraphWrapper,
    LinkedPipelinesColumn,
    StageColumnComponent,
  },
  props: {
    configPaths: {
      type: Object,
      required: true,
      validator: validateConfigPaths,
    },
    pipeline: {
      type: Object,
      required: true,
    },
    viewType: {
      type: String,
      required: true,
    },
    isLinkedPipeline: {
      type: Boolean,
      required: false,
      default: false,
    },
    pipelineLayers: {
      type: Array,
      required: false,
      default: () => [],
    },
    type: {
      type: String,
      required: false,
      default: MAIN,
    },
  },
  pipelineTypeConstants: {
    DOWNSTREAM,
    UPSTREAM,
  },
  CONTAINER_REF: 'PIPELINE_LINKS_CONTAINER_REF',
  BASE_CONTAINER_ID: 'pipeline-links-container',
  data() {
    return {
      hoveredJobName: '',
      hoveredSourceJobName: '',
      highlightedJobs: [],
      measurements: {
        width: 0,
        height: 0,
      },
      pipelineExpanded: {
        jobName: '',
        expanded: false,
      },
    };
  },
  computed: {
    containerId() {
      return `${this.$options.BASE_CONTAINER_ID}-${this.pipeline.id}`;
    },
    downstreamPipelines() {
      return this.hasDownstreamPipelines ? this.pipeline.downstream : [];
    },
    layout() {
      return this.isStageView ? this.pipeline.stages : this.generateColumnsFromLayersList();
    },
    hasDownstreamPipelines() {
      return Boolean(this.pipeline?.downstream?.length > 0);
    },
    hasUpstreamPipelines() {
      return Boolean(this.pipeline?.upstream?.length > 0);
    },
    isStageView() {
      return this.viewType === STAGE_VIEW;
    },
    metricsConfig() {
      return {
        path: this.configPaths.metricsPath,
        collectMetrics: true,
      };
    },
    shouldHideLinks() {
      return this.isStageView;
    },
    shouldShowStageName() {
      return !this.isStageView;
    },
    // The show downstream check prevents showing redundant linked columns
    showDownstreamPipelines() {
      return (
        this.hasDownstreamPipelines && this.type !== this.$options.pipelineTypeConstants.UPSTREAM
      );
    },
    // The show upstream check prevents showing redundant linked columns
    showUpstreamPipelines() {
      return (
        this.hasUpstreamPipelines && this.type !== this.$options.pipelineTypeConstants.DOWNSTREAM
      );
    },
    upstreamPipelines() {
      return this.hasUpstreamPipelines ? this.pipeline.upstream : [];
    },
  },
  errorCaptured(err, _vm, info) {
    reportToSentry(this.$options.name, `error: ${err}, info: ${info}`);
  },
  mounted() {
    this.getMeasurements();
  },
  methods: {
    generateColumnsFromLayersList() {
      return this.pipelineLayers.map((layers, idx) => {
        /*
          look up the groups in each layer,
          then add each set of layer groups to a stage-like object
        */

        const groups = layers.map((id) => {
          const { stageIdx, groupIdx } = this.pipeline.stagesLookup[id];
          return this.pipeline.stages?.[stageIdx]?.groups?.[groupIdx];
        });

        return {
          name: '',
          id: `layer-${idx}`,
          status: { action: null },
          groups: groups.filter(Boolean),
        };
      });
    },
    getMeasurements() {
      this.measurements = {
        width: this.$refs[this.containerId].scrollWidth,
        height: this.$refs[this.containerId].scrollHeight,
      };
    },
    onError(payload) {
      this.$emit('error', payload);
    },
    setJob(jobName) {
      this.hoveredJobName = jobName;
    },
    setSourceJob(jobName) {
      this.hoveredSourceJobName = jobName;
    },
    slidePipelineContainer() {
      this.$refs.mainPipelineContainer.scrollBy({
        left: ONE_COL_WIDTH,
        top: 0,
        behavior: 'smooth',
      });
    },
    togglePipelineExpanded(jobName, expanded) {
      this.pipelineExpanded = {
        expanded,
        jobName: expanded ? jobName : '',
      };
    },
    updateHighlightedJobs(jobs) {
      this.highlightedJobs = jobs;
    },
  },
};
</script>
<template>
  <div class="js-pipeline-graph">
    <div
      ref="mainPipelineContainer"
      class="gl-display-flex gl-position-relative gl-bg-gray-10 gl-white-space-nowrap"
      :class="{ 'gl-pipeline-min-h gl-py-5 gl-overflow-auto': !isLinkedPipeline }"
    >
      <linked-graph-wrapper>
        <template #upstream>
          <linked-pipelines-column
            v-if="showUpstreamPipelines"
            :config-paths="configPaths"
            :linked-pipelines="upstreamPipelines"
            :column-title="__('Upstream')"
            :type="$options.pipelineTypeConstants.UPSTREAM"
            :view-type="viewType"
            @error="onError"
          />
        </template>
        <template #main>
          <div :id="containerId" :ref="containerId">
            <links-layer
              :pipeline-data="layout"
              :pipeline-id="pipeline.id"
              :container-id="containerId"
              :container-measurements="measurements"
              :highlighted-job="hoveredJobName"
              :metrics-config="metricsConfig"
              :never-show-links="shouldHideLinks"
              :view-type="viewType"
              default-link-color="gl-stroke-transparent"
              @error="onError"
              @highlightedJobsChange="updateHighlightedJobs"
            >
              <stage-column-component
                v-for="column in layout"
                :key="column.id || column.name"
                :name="column.name"
                :groups="column.groups"
                :action="column.status.action"
                :highlighted-jobs="highlightedJobs"
                :show-stage-name="shouldShowStageName"
                :job-hovered="hoveredJobName"
                :source-job-hovered="hoveredSourceJobName"
                :pipeline-expanded="pipelineExpanded"
                :pipeline-id="pipeline.id"
                @refreshPipelineGraph="$emit('refreshPipelineGraph')"
                @jobHover="setJob"
                @updateMeasurements="getMeasurements"
              />
            </links-layer>
          </div>
        </template>
        <template #downstream>
          <linked-pipelines-column
            v-if="showDownstreamPipelines"
            class="gl-mr-6"
            :config-paths="configPaths"
            :linked-pipelines="downstreamPipelines"
            :column-title="__('Downstream')"
            :type="$options.pipelineTypeConstants.DOWNSTREAM"
            :view-type="viewType"
            @downstreamHovered="setSourceJob"
            @pipelineExpandToggle="togglePipelineExpanded"
            @scrollContainer="slidePipelineContainer"
            @error="onError"
          />
        </template>
      </linked-graph-wrapper>
    </div>
  </div>
</template>
