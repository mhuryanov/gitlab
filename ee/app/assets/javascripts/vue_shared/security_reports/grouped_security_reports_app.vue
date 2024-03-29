<script>
import { GlButton, GlSprintf, GlLink, GlModalDirective } from '@gitlab/ui';
import { once } from 'lodash';
import { mapActions, mapState, mapGetters } from 'vuex';
import { componentNames } from 'ee/reports/components/issue_body';
import FuzzingArtifactsDownload from 'ee/security_dashboard/components/fuzzing_artifacts_download.vue';
import { fetchPolicies } from '~/lib/graphql';
import { mrStates } from '~/mr_popover/constants';
import GroupedIssuesList from '~/reports/components/grouped_issues_list.vue';
import ReportSection from '~/reports/components/report_section.vue';
import SummaryRow from '~/reports/components/summary_row.vue';
import { LOADING } from '~/reports/constants';
import Tracking from '~/tracking';
import SecuritySummary from '~/vue_shared/security_reports/components/security_summary.vue';
import ArtifactDownload from './components/artifact_download.vue';
import DastModal from './components/dast_modal.vue';
import IssueModal from './components/modal.vue';
import { securityReportTypeEnumToReportType } from './constants';
import securityReportSummaryQuery from './graphql/mr_security_report_summary.graphql';
import securityReportsMixin from './mixins/security_report_mixin';
import { vulnerabilityModalMixin } from './mixins/vulnerability_modal_mixin';
import createStore from './store';
import {
  MODULE_CONTAINER_SCANNING,
  MODULE_API_FUZZING,
  MODULE_COVERAGE_FUZZING,
  MODULE_DAST,
  MODULE_DEPENDENCY_SCANNING,
  MODULE_SAST,
  MODULE_SECRET_DETECTION,
  trackMrSecurityReportDetails,
} from './store/constants';

export default {
  store: createStore(),
  components: {
    ArtifactDownload,
    GroupedIssuesList,
    ReportSection,
    SummaryRow,
    SecuritySummary,
    IssueModal,
    GlSprintf,
    GlLink,
    DastModal,
    GlButton,
    FuzzingArtifactsDownload,
  },
  directives: {
    'gl-modal': GlModalDirective,
  },
  mixins: [securityReportsMixin, vulnerabilityModalMixin()],
  apollo: {
    dastSummary: {
      query: securityReportSummaryQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return {
          fullPath: this.projectFullPath,
          pipelineIid: this.pipelineIid,
        };
      },
      update(data) {
        const dast = data?.project?.pipeline?.securityReportSummary?.dast;
        return dast && Object.keys(dast).length ? dast : null;
      },
    },
  },
  props: {
    enabledReports: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    headBlobPath: {
      type: String,
      required: true,
    },
    baseBlobPath: {
      type: String,
      required: false,
      default: null,
    },
    sourceBranch: {
      type: String,
      required: false,
      default: null,
    },
    targetBranch: {
      type: String,
      required: false,
      default: null,
    },
    sastHelpPath: {
      type: String,
      required: false,
      default: '',
    },
    containerScanningHelpPath: {
      type: String,
      required: false,
      default: '',
    },
    dastHelpPath: {
      type: String,
      required: false,
      default: '',
    },
    apiFuzzingHelpPath: {
      type: String,
      required: false,
      default: '',
    },
    coverageFuzzingHelpPath: {
      type: String,
      required: false,
      default: '',
    },
    dependencyScanningHelpPath: {
      type: String,
      required: false,
      default: '',
    },
    secretScanningHelpPath: {
      type: String,
      required: false,
      default: '',
    },
    canReadVulnerabilityFeedback: {
      type: Boolean,
      required: false,
      default: false,
    },
    vulnerabilityFeedbackPath: {
      type: String,
      required: false,
      default: '',
    },
    createVulnerabilityFeedbackIssuePath: {
      type: String,
      required: false,
      default: '',
    },
    createVulnerabilityFeedbackMergeRequestPath: {
      type: String,
      required: false,
      default: '',
    },
    createVulnerabilityFeedbackDismissalPath: {
      type: String,
      required: false,
      default: '',
    },
    pipelineId: {
      type: Number,
      required: false,
      default: null,
    },
    pipelineIid: {
      type: Number,
      required: false,
      default: null,
    },
    pipelinePath: {
      type: String,
      required: false,
      default: undefined,
    },
    divergedCommitsCount: {
      type: Number,
      required: false,
      default: 0,
    },
    mrState: {
      type: String,
      required: false,
      default: null,
    },
    targetBranchTreePath: {
      type: String,
      required: false,
      default: '',
    },
    newPipelinePath: {
      type: String,
      required: false,
      default: '',
    },
    projectId: {
      type: Number,
      required: false,
      default: null,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
    apiFuzzingComparisonPath: {
      type: String,
      required: false,
      default: '',
    },
    containerScanningComparisonPath: {
      type: String,
      required: false,
      default: '',
    },
    coverageFuzzingComparisonPath: {
      type: String,
      required: false,
      default: '',
    },
    dastComparisonPath: {
      type: String,
      required: false,
      default: '',
    },
    dependencyScanningComparisonPath: {
      type: String,
      required: false,
      default: '',
    },
    sastComparisonPath: {
      type: String,
      required: false,
      default: '',
    },
    secretScanningComparisonPath: {
      type: String,
      required: false,
      default: '',
    },
    targetProjectFullPath: {
      type: String,
      required: true,
    },
    mrIid: {
      type: Number,
      required: true,
    },
  },
  componentNames,
  computed: {
    ...mapState([
      MODULE_SAST,
      MODULE_CONTAINER_SCANNING,
      MODULE_DAST,
      MODULE_API_FUZZING,
      MODULE_COVERAGE_FUZZING,
      MODULE_DEPENDENCY_SCANNING,
      MODULE_SECRET_DETECTION,
      'summaryCounts',
      'modal',
      'isCreatingIssue',
      'isDismissingVulnerability',
      'isCreatingMergeRequest',
    ]),
    ...mapGetters([
      'groupedSummaryText',
      'summaryStatus',
      'groupedContainerScanningText',
      'groupedDastText',
      'groupedDependencyText',
      'groupedCoverageFuzzingText',
      'containerScanningStatusIcon',
      'dastStatusIcon',
      'dependencyScanningStatusIcon',
      'coverageFuzzingStatusIcon',
      'isBaseSecurityReportOutOfDate',
      'canCreateIssue',
      'canCreateMergeRequest',
      'canDismissVulnerability',
    ]),
    ...mapGetters(MODULE_SAST, ['groupedSastText', 'sastStatusIcon']),
    ...mapGetters(MODULE_SECRET_DETECTION, [
      'groupedSecretDetectionText',
      'secretDetectionStatusIcon',
    ]),
    ...mapGetters(MODULE_API_FUZZING, ['groupedApiFuzzingText', 'apiFuzzingStatusIcon']),
    ...mapGetters('pipelineJobs', ['hasFuzzingArtifacts', 'fuzzingJobsWithArtifact']),
    securityTab() {
      return `${this.pipelinePath}/security`;
    },
    hasContainerScanningReports() {
      return this.enabledReports.containerScanning;
    },
    hasDependencyScanningReports() {
      return this.enabledReports.dependencyScanning;
    },
    hasDastReports() {
      return this.enabledReports.dast;
    },
    hasApiFuzzingReports() {
      return this.enabledReports.apiFuzzing;
    },
    hasCoverageFuzzingReports() {
      return this.enabledReports.coverageFuzzing;
    },
    hasSastReports() {
      return this.enabledReports.sast;
    },
    hasSecretDetectionReports() {
      return this.enabledReports.secretDetection;
    },
    isMRActive() {
      return this.mrState !== mrStates.merged && this.mrState !== mrStates.closed;
    },
    isMRBranchOutdated() {
      return this.divergedCommitsCount > 0;
    },
    hasDastScannedResources() {
      return this.dastSummary?.scannedResourcesCount > 0;
    },
    handleToggleEvent() {
      return once(() => {
        const { category, action } = trackMrSecurityReportDetails;
        Tracking.event(category, action);
      });
    },
    dastDownloadLink() {
      return this.dastSummary?.scannedResourcesCsvPath || '';
    },
    hasApiFuzzingIssues() {
      return this.hasIssuesForReportType(MODULE_API_FUZZING);
    },
    hasCoverageFuzzingIssues() {
      return this.hasIssuesForReportType(MODULE_COVERAGE_FUZZING);
    },
    hasSastIssues() {
      return this.hasIssuesForReportType(MODULE_SAST);
    },
    hasDependencyScanningIssues() {
      return this.hasIssuesForReportType(MODULE_DEPENDENCY_SCANNING);
    },
    hasContainerScanningIssues() {
      return this.hasIssuesForReportType(MODULE_CONTAINER_SCANNING);
    },
    hasDastIssues() {
      return this.hasIssuesForReportType(MODULE_DAST);
    },
    hasSecretDetectionIssues() {
      return this.hasIssuesForReportType(MODULE_SECRET_DETECTION);
    },
    shouldShowDownloadGuidance() {
      return this.targetProjectFullPath && this.mrIid && this.summaryStatus !== LOADING;
    },
  },

  created() {
    this.setHeadBlobPath(this.headBlobPath);
    this.setBaseBlobPath(this.baseBlobPath);
    this.setSourceBranch(this.sourceBranch);

    this.setCanReadVulnerabilityFeedback(this.canReadVulnerabilityFeedback);
    this.setVulnerabilityFeedbackPath(this.vulnerabilityFeedbackPath);
    this.setCreateVulnerabilityFeedbackIssuePath(this.createVulnerabilityFeedbackIssuePath);
    this.setCreateVulnerabilityFeedbackMergeRequestPath(
      this.createVulnerabilityFeedbackMergeRequestPath,
    );
    this.setCreateVulnerabilityFeedbackDismissalPath(this.createVulnerabilityFeedbackDismissalPath);
    this.setProjectId(this.projectId);
    this.setPipelineId(this.pipelineId);
    this.setPipelineJobsId(this.pipelineId);

    if (this.sastComparisonPath && this.hasSastReports) {
      this.setSastDiffEndpoint(this.sastComparisonPath);
      this.fetchSastDiff();
    }

    if (this.containerScanningComparisonPath && this.hasContainerScanningReports) {
      this.setContainerScanningDiffEndpoint(this.containerScanningComparisonPath);
      this.fetchContainerScanningDiff();
    }

    if (this.dastComparisonPath && this.hasDastReports) {
      this.setDastDiffEndpoint(this.dastComparisonPath);
      this.fetchDastDiff();
    }

    if (this.dependencyScanningComparisonPath && this.hasDependencyScanningReports) {
      this.setDependencyScanningDiffEndpoint(this.dependencyScanningComparisonPath);
      this.fetchDependencyScanningDiff();
    }

    if (this.secretScanningComparisonPath && this.hasSecretDetectionReports) {
      this.setSecretDetectionDiffEndpoint(this.secretScanningComparisonPath);
      this.fetchSecretDetectionDiff();
    }

    if (this.coverageFuzzingComparisonPath && this.hasCoverageFuzzingReports) {
      this.setCoverageFuzzingDiffEndpoint(this.coverageFuzzingComparisonPath);
      this.fetchCoverageFuzzingDiff();
      this.fetchPipelineJobs();
    }

    if (this.apiFuzzingComparisonPath && this.hasApiFuzzingReports) {
      this.setApiFuzzingDiffEndpoint(this.apiFuzzingComparisonPath);
      this.fetchApiFuzzingDiff();
    }
  },
  methods: {
    ...mapActions([
      'setAppType',
      'setHeadBlobPath',
      'setBaseBlobPath',
      'setSourceBranch',
      'setCanReadVulnerabilityFeedback',
      'setVulnerabilityFeedbackPath',
      'setCreateVulnerabilityFeedbackIssuePath',
      'setCreateVulnerabilityFeedbackMergeRequestPath',
      'setCreateVulnerabilityFeedbackDismissalPath',
      'setPipelineId',
      'createNewIssue',
      'createMergeRequest',
      'openDismissalCommentBox',
      'closeDismissalCommentBox',
      'downloadPatch',
      'showDismissalDeleteButtons',
      'hideDismissalDeleteButtons',
      'fetchContainerScanningDiff',
      'setContainerScanningDiffEndpoint',
      'fetchDependencyScanningDiff',
      'setDependencyScanningDiffEndpoint',
      'fetchDastDiff',
      'setDastDiffEndpoint',
      'fetchCoverageFuzzingDiff',
      'setCoverageFuzzingDiffEndpoint',
    ]),
    ...mapActions(MODULE_SAST, {
      setSastDiffEndpoint: 'setDiffEndpoint',
      fetchSastDiff: 'fetchDiff',
    }),
    ...mapActions(MODULE_SECRET_DETECTION, {
      setSecretDetectionDiffEndpoint: 'setDiffEndpoint',
      fetchSecretDetectionDiff: 'fetchDiff',
    }),
    ...mapActions(MODULE_API_FUZZING, {
      setApiFuzzingDiffEndpoint: 'setDiffEndpoint',
      fetchApiFuzzingDiff: 'fetchDiff',
    }),
    ...mapActions('pipelineJobs', ['fetchPipelineJobs', 'setPipelineJobsPath', 'setProjectId']),
    ...mapActions('pipelineJobs', {
      setPipelineJobsId: 'setPipelineId',
    }),
    hasIssuesForReportType(reportType) {
      return Boolean(this[reportType]?.newIssues.length || this[reportType]?.resolvedIssues.length);
    },
  },
  summarySlots: ['success', 'error', 'loading'],
  reportTypes: securityReportTypeEnumToReportType,
};
</script>
<template>
  <report-section
    :status="summaryStatus"
    :has-issues="true"
    :should-emit-toggle-event="true"
    class="mr-widget-border-top grouped-security-reports mr-report"
    data-qa-selector="vulnerability_report_grouped"
    track-action="users_expanding_security_report"
    @toggleEvent="handleToggleEvent"
  >
    <template v-for="slot in $options.summarySlots" #[slot]>
      <security-summary :key="slot" :message="groupedSummaryText" />
    </template>

    <template v-if="pipelinePath" #action-buttons>
      <gl-button
        :href="securityTab"
        target="_blank"
        icon="external-link"
        class="gl-mr-3 report-btn"
      >
        {{ s__('ciReport|View full report') }}
      </gl-button>
    </template>

    <template v-if="isMRActive && isBaseSecurityReportOutOfDate" #sub-heading>
      <div class="text-secondary-700 text-1">
        <gl-sprintf
          v-if="isMRBranchOutdated"
          :message="
            __(
              'Security report is out of date. Please update your branch with the latest changes from the target branch (%{targetBranchName})',
            )
          "
        >
          <template #targetBranchName>
            <gl-link class="text-1" :href="targetBranchTreePath">{{ targetBranch }}</gl-link>
          </template>
        </gl-sprintf>

        <gl-sprintf
          v-else
          :message="
            __(
              'Security report is out of date. Run %{newPipelineLinkStart}a new pipeline%{newPipelineLinkEnd} for the target branch (%{targetBranchName})',
            )
          "
        >
          <template #newPipelineLink="{ content }">
            <gl-link class="text-1" :href="`${newPipelinePath}?ref=${targetBranch}`">{{
              content
            }}</gl-link>
          </template>
          <template #targetBranchName>
            <gl-link class="text-1" :href="targetBranchTreePath">{{ targetBranch }}</gl-link>
          </template>
        </gl-sprintf>
      </div>
    </template>

    <template #body>
      <div class="mr-widget-grouped-section report-block">
        <template v-if="hasSastReports">
          <summary-row
            :status-icon="sastStatusIcon"
            :popover-options="sastPopover"
            class="js-sast-widget"
            data-qa-selector="sast_scan_report"
          >
            <template #summary>
              <security-summary :message="groupedSastText" />
            </template>
          </summary-row>

          <grouped-issues-list
            v-if="hasSastIssues"
            :unresolved-issues="sast.newIssues"
            :resolved-issues="sast.resolvedIssues"
            :component="$options.componentNames.SecurityIssueBody"
            data-testid="sast-issues-list"
          />
        </template>

        <template v-if="hasDependencyScanningReports">
          <summary-row
            :status-icon="dependencyScanningStatusIcon"
            :popover-options="dependencyScanningPopover"
            class="js-dependency-scanning-widget"
            data-qa-selector="dependency_scan_report"
          >
            <template #summary>
              <security-summary :message="groupedDependencyText" />
            </template>
          </summary-row>

          <grouped-issues-list
            v-if="hasDependencyScanningIssues"
            :unresolved-issues="dependencyScanning.newIssues"
            :resolved-issues="dependencyScanning.resolvedIssues"
            :component="$options.componentNames.SecurityIssueBody"
            data-testid="dependency-scanning-issues-list"
          />
        </template>

        <template v-if="hasContainerScanningReports">
          <summary-row
            :status-icon="containerScanningStatusIcon"
            :popover-options="containerScanningPopover"
            class="js-container-scanning"
            data-qa-selector="container_scan_report"
          >
            <template #summary>
              <security-summary :message="groupedContainerScanningText" />
            </template>
          </summary-row>

          <grouped-issues-list
            v-if="hasContainerScanningIssues"
            :unresolved-issues="containerScanning.newIssues"
            :resolved-issues="containerScanning.resolvedIssues"
            :component="$options.componentNames.SecurityIssueBody"
            data-testid="container-scanning-issues-list"
          />
        </template>

        <template v-if="hasDastReports">
          <summary-row
            :status-icon="dastStatusIcon"
            :popover-options="dastPopover"
            class="js-dast-widget"
            data-qa-selector="dast_scan_report"
          >
            <template #summary>
              <security-summary :message="groupedDastText" />
            </template>

            <template v-if="hasDastScannedResources">
              <div class="text-nowrap">
                {{ n__('%d URL scanned', '%d URLs scanned', dastSummary.scannedResourcesCount) }}
              </div>
              <gl-link v-gl-modal.dastUrl class="ml-2" data-testid="dast-ci-job-link">
                {{ __('View details') }}
              </gl-link>
              <dast-modal
                :scanned-urls="dastSummary.scannedResources.nodes"
                :scanned-resources-count="dastSummary.scannedResourcesCount"
                :download-link="dastDownloadLink"
              />
            </template>
          </summary-row>
          <grouped-issues-list
            v-if="hasDastIssues"
            :unresolved-issues="dast.newIssues"
            :resolved-issues="dast.resolvedIssues"
            :component="$options.componentNames.SecurityIssueBody"
            data-testid="dast-issues-list"
          />
        </template>

        <template v-if="hasSecretDetectionReports">
          <summary-row
            :status-icon="secretDetectionStatusIcon"
            :popover-options="secretScanningPopover"
            class="js-secret-scanning"
            data-testid="secret-scan-report"
          >
            <template #summary>
              <security-summary :message="groupedSecretDetectionText" />
            </template>
          </summary-row>

          <grouped-issues-list
            v-if="hasSecretDetectionIssues"
            :unresolved-issues="secretDetection.newIssues"
            :resolved-issues="secretDetection.resolvedIssues"
            :component="$options.componentNames.SecurityIssueBody"
            data-testid="secret-scanning-issues-list"
          />
        </template>

        <template v-if="hasCoverageFuzzingReports">
          <summary-row
            :status-icon="coverageFuzzingStatusIcon"
            :popover-options="coverageFuzzingPopover"
            class="js-coverage-fuzzing-widget"
            data-qa-selector="coverage_fuzzing_report"
          >
            <template #summary>
              <security-summary :message="groupedCoverageFuzzingText" />
            </template>
            <fuzzing-artifacts-download
              v-if="hasFuzzingArtifacts"
              :jobs="fuzzingJobsWithArtifact"
              :project-id="projectId"
            />
          </summary-row>

          <grouped-issues-list
            v-if="hasCoverageFuzzingIssues"
            :unresolved-issues="coverageFuzzing.newIssues"
            :resolved-issues="coverageFuzzing.resolvedIssues"
            :component="$options.componentNames.SecurityIssueBody"
            data-testid="coverage-fuzzing-issues-list"
          />
        </template>

        <template v-if="hasApiFuzzingReports">
          <summary-row
            :status-icon="apiFuzzingStatusIcon"
            :popover-options="apiFuzzingPopover"
            class="js-api-fuzzing-widget"
            data-qa-selector="api_fuzzing_report"
          >
            <template #summary>
              <security-summary :message="groupedApiFuzzingText" />
            </template>

            <artifact-download
              v-if="shouldShowDownloadGuidance"
              :report-types="[$options.reportTypes.API_FUZZING]"
              :target-project-full-path="targetProjectFullPath"
              :mr-iid="mrIid"
            />
          </summary-row>

          <grouped-issues-list
            v-if="hasApiFuzzingIssues"
            :unresolved-issues="apiFuzzing.newIssues"
            :resolved-issues="apiFuzzing.resolvedIssues"
            :component="$options.componentNames.SecurityIssueBody"
            class="report-block-group-list"
            data-testid="api-fuzzing-issues-list"
          />
        </template>

        <issue-modal
          :modal="modal"
          :can-create-issue="canCreateIssue"
          :can-create-merge-request="canCreateMergeRequest"
          :can-dismiss-vulnerability="canDismissVulnerability"
          :is-creating-issue="isCreatingIssue"
          :is-dismissing-vulnerability="isDismissingVulnerability"
          :is-creating-merge-request="isCreatingMergeRequest"
          @closeDismissalCommentBox="closeDismissalCommentBox()"
          @createMergeRequest="createMergeRequest"
          @createNewIssue="createNewIssue"
          @dismissVulnerability="handleDismissVulnerability"
          @openDismissalCommentBox="openDismissalCommentBox()"
          @editVulnerabilityDismissalComment="openDismissalCommentBox()"
          @revertDismissVulnerability="handleRevertDismissVulnerability"
          @downloadPatch="downloadPatch"
          @addDismissalComment="handleAddDismissalComment({ comment: $event })"
          @deleteDismissalComment="handleDeleteDismissalComment"
          @showDismissalDeleteButtons="showDismissalDeleteButtons"
          @hideDismissalDeleteButtons="hideDismissalDeleteButtons"
        />
      </div>
    </template>
  </report-section>
</template>
