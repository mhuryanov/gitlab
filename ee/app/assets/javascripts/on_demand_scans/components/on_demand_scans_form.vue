<script>
import {
  GlAlert,
  GlButton,
  GlCard,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlLink,
  GlSkeletonLoader,
  GlSprintf,
  GlSafeHtmlDirective,
  GlTooltipDirective,
} from '@gitlab/ui';
import * as Sentry from '@sentry/browser';
import {
  SCAN_TYPE_LABEL,
  SCAN_TYPE,
} from 'ee/security_configuration/dast_scanner_profiles/constants';
import { EXCLUDED_URLS_SEPARATOR } from 'ee/security_configuration/dast_site_profiles_form/constants';
import { DAST_SITE_VALIDATION_STATUS } from 'ee/security_configuration/dast_site_validation/constants';
import { initFormField } from 'ee/security_configuration/utils';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { serializeFormObject } from '~/lib/utils/forms';
import { redirectTo, queryToObject } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import RefSelector from '~/ref/components/ref_selector.vue';
import { REF_TYPE_BRANCHES } from '~/ref/constants';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import validation from '~/vue_shared/directives/validation';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import dastProfileCreateMutation from '../graphql/dast_profile_create.mutation.graphql';
import dastProfileUpdateMutation from '../graphql/dast_profile_update.mutation.graphql';
import {
  ERROR_RUN_SCAN,
  ERROR_FETCH_SCANNER_PROFILES,
  ERROR_FETCH_SITE_PROFILES,
  ERROR_MESSAGES,
  SCANNER_PROFILES_QUERY,
  SITE_PROFILES_QUERY,
  TYPE_SITE_PROFILE,
  TYPE_SCANNER_PROFILE,
} from '../settings';
import ScannerProfileSelector from './profile_selector/scanner_profile_selector.vue';
import SiteProfileSelector from './profile_selector/site_profile_selector.vue';
import ProfileSelectorSummaryCell from './profile_selector/summary_cell.vue';

export const ON_DEMAND_SCANS_STORAGE_KEY = 'on-demand-scans-new-form';

const createProfilesApolloOptions = (name, field, { fetchQuery, fetchError }) => ({
  query: fetchQuery,
  variables() {
    return {
      fullPath: this.projectPath,
    };
  },
  update(data) {
    const edges = data?.project?.[name]?.edges ?? [];
    if (edges.length === 1) {
      this[field] = edges[0].node.id;
    }
    return edges.map(({ node }) => node);
  },
  error(e) {
    Sentry.captureException(e);
    this.showErrors(fetchError);
  },
});

export default {
  SCAN_TYPE_LABEL,
  enabledRefTypes: [REF_TYPE_BRANCHES],
  saveAndRunScanBtnId: 'scan-submit-button',
  saveScanBtnId: 'scan-save-button',
  components: {
    RefSelector,
    ProfileSelectorSummaryCell,
    ScannerProfileSelector,
    SiteProfileSelector,
    GlAlert,
    GlButton,
    GlCard,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlLink,
    GlSkeletonLoader,
    GlSprintf,
    LocalStorageSync,
  },
  directives: {
    SafeHtml: GlSafeHtmlDirective,
    GlTooltip: GlTooltipDirective,
    validation: validation(),
  },
  mixins: [glFeatureFlagsMixin()],
  apollo: {
    scannerProfiles: createProfilesApolloOptions(
      'scannerProfiles',
      'selectedScannerProfileId',
      SCANNER_PROFILES_QUERY,
    ),
    siteProfiles: createProfilesApolloOptions(
      'siteProfiles',
      'selectedSiteProfileId',
      SITE_PROFILES_QUERY,
    ),
  },
  inject: {
    dastSiteValidationDocsPath: {
      default: '',
    },
    profilesLibraryPath: {
      default: '',
    },
  },
  props: {
    helpPagePath: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    defaultBranch: {
      type: String,
      required: false,
      default: '',
    },
    dastScan: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      form: {
        showValidation: false,
        state: false,
        fields: {
          name: initFormField({ value: this.dastScan?.name ?? '' }),
          description: initFormField({
            value: this.dastScan?.description ?? '',
            required: false,
            skipValidation: true,
          }),
        },
      },
      scannerProfiles: [],
      siteProfiles: [],
      selectedBranch: this.dastScan?.branch?.name ?? this.defaultBranch,
      selectedScannerProfileId: this.dastScan?.scannerProfileId || null,
      selectedSiteProfileId: this.dastScan?.siteProfileId || null,
      loading: false,
      errorType: null,
      errors: [],
      showAlert: false,
      clearStorage: false,
    };
  },
  computed: {
    isEdit() {
      return Boolean(this.dastScan?.id);
    },
    title() {
      return this.isEdit
        ? s__('OnDemandScans|Edit on-demand DAST scan')
        : s__('OnDemandScans|New on-demand DAST scan');
    },
    selectedScannerProfile() {
      return this.selectedScannerProfileId
        ? this.scannerProfiles.find(({ id }) => id === this.selectedScannerProfileId)
        : null;
    },
    selectedSiteProfile() {
      return this.selectedSiteProfileId
        ? this.siteProfiles.find(({ id }) => id === this.selectedSiteProfileId)
        : null;
    },
    errorMessage() {
      return ERROR_MESSAGES[this.errorType] || null;
    },
    isLoadingProfiles() {
      return ['scannerProfiles', 'siteProfiles'].some((name) => this.$apollo.queries[name].loading);
    },
    failedToLoadProfiles() {
      return [ERROR_FETCH_SCANNER_PROFILES, ERROR_FETCH_SITE_PROFILES].includes(this.errorType);
    },
    someFieldEmpty() {
      const { selectedScannerProfile, selectedSiteProfile } = this;
      return !selectedScannerProfile || !selectedSiteProfile;
    },
    isActiveScannerProfile() {
      return this.selectedScannerProfile?.scanType === SCAN_TYPE.ACTIVE;
    },
    isValidatedSiteProfile() {
      return this.selectedSiteProfile?.validationStatus === DAST_SITE_VALIDATION_STATUS.PASSED;
    },
    hasProfilesConflict() {
      return !this.someFieldEmpty && this.isActiveScannerProfile && !this.isValidatedSiteProfile;
    },
    isFormInvalid() {
      return this.someFieldEmpty || this.hasProfilesConflict;
    },
    isSubmitButtonDisabled() {
      const {
        isFormInvalid,
        loading,
        $options: { saveAndRunScanBtnId },
      } = this;
      return isFormInvalid || (loading && loading !== saveAndRunScanBtnId);
    },
    isSaveButtonDisabled() {
      const {
        isFormInvalid,
        loading,
        $options: { saveScanBtnId },
      } = this;
      return isFormInvalid || (loading && loading !== saveScanBtnId);
    },
    formFieldValues() {
      const { selectedScannerProfileId, selectedSiteProfileId, selectedBranch } = this;
      return {
        ...serializeFormObject(this.form.fields),
        selectedScannerProfileId,
        selectedSiteProfileId,
        selectedBranch,
      };
    },
    hasExcludedUrls() {
      return this.selectedSiteProfile.excludedUrls?.length > 0;
    },
    storageKey() {
      return `${this.projectPath}/${ON_DEMAND_SCANS_STORAGE_KEY}`;
    },
  },
  created() {
    const params = queryToObject(window.location.search);

    this.selectedSiteProfileId = params.site_profile_id
      ? convertToGraphQLId(TYPE_SITE_PROFILE, params.site_profile_id)
      : this.selectedSiteProfileId;
    this.selectedScannerProfileId = params.scanner_profile_id
      ? convertToGraphQLId(TYPE_SCANNER_PROFILE, params.scanner_profile_id)
      : this.selectedScannerProfileId;
  },
  methods: {
    onSubmit({ runAfter = true, button = this.$options.saveAndRunScanBtnId } = {}) {
      this.form.showValidation = true;
      if (!this.form.state) {
        return;
      }

      this.loading = button;
      this.hideErrors();
      const mutation = this.isEdit ? dastProfileUpdateMutation : dastProfileCreateMutation;
      const responseType = this.isEdit ? 'dastProfileUpdate' : 'dastProfileCreate';
      const input = {
        fullPath: this.projectPath,
        dastScannerProfileId: this.selectedScannerProfile.id,
        dastSiteProfileId: this.selectedSiteProfile.id,
        branchName: this.selectedBranch,
        ...(this.isEdit ? { id: this.dastScan.id } : {}),
        ...serializeFormObject(this.form.fields),
        [this.isEdit ? 'runAfterUpdate' : 'runAfterCreate']: runAfter,
      };

      this.$apollo
        .mutate({
          mutation,
          variables: {
            input,
          },
        })
        .then(({ data }) => {
          const response = data[responseType];
          const { errors } = response;
          if (errors?.length) {
            this.showErrors(ERROR_RUN_SCAN, errors);
            this.loading = false;
          } else if (!runAfter) {
            redirectTo(this.profilesLibraryPath);
            this.clearStorage = true;
          } else {
            this.clearStorage = true;
            redirectTo(response.pipelineUrl);
          }
        })
        .catch((e) => {
          Sentry.captureException(e);
          this.showErrors(ERROR_RUN_SCAN);
          this.loading = false;
        });
    },
    onCancelClicked() {
      this.clearStorage = true;
      redirectTo(this.profilesLibraryPath);
    },
    showErrors(errorType, errors = []) {
      this.errorType = errorType;
      this.errors = errors;
      this.showAlert = true;
    },
    hideErrors() {
      this.errorType = null;
      this.errors = [];
      this.showAlert = false;
    },
    updateFromStorage(val) {
      const {
        selectedSiteProfileId,
        selectedScannerProfileId,
        name,
        description,
        selectedBranch,
      } = val;

      this.form.fields.name.value = name ?? this.form.fields.name.value;
      this.form.fields.description.value = description ?? this.form.fields.description.value;
      this.selectedBranch = selectedBranch;
      // precedence is given to profile IDs passed from the query params
      this.selectedSiteProfileId = this.selectedSiteProfileId ?? selectedSiteProfileId;
      this.selectedScannerProfileId = this.selectedScannerProfileId ?? selectedScannerProfileId;
    },
  },
  EXCLUDED_URLS_SEPARATOR,
};
</script>

<template>
  <gl-form novalidate @submit.prevent="onSubmit()">
    <local-storage-sync
      v-if="!isEdit"
      as-json
      :storage-key="storageKey"
      :clear="clearStorage"
      :value="formFieldValues"
      @input="updateFromStorage"
    />
    <header class="gl-mb-6">
      <div class="gl-mt-6 gl-display-flex">
        <h2 class="gl-flex-grow-1 gl-my-0">{{ title }}</h2>
        <gl-button :href="profilesLibraryPath" data-testid="manage-profiles-link">
          {{ s__('OnDemandScans|Manage DAST scans') }}
        </gl-button>
      </div>
      <p>
        <gl-sprintf
          :message="
            s__(
              'OnDemandScans|On-demand scans run outside the DevOps cycle and find vulnerabilities in your projects. %{learnMoreLinkStart}Learn more%{learnMoreLinkEnd}',
            )
          "
        >
          <template #learnMoreLink="{ content }">
            <gl-link :href="helpPagePath">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
    </header>

    <gl-alert
      v-if="showAlert"
      variant="danger"
      class="gl-mb-5"
      data-testid="on-demand-scan-error"
      :dismissible="!failedToLoadProfiles"
      @dismiss="hideErrors"
    >
      {{ errorMessage }}
      <ul v-if="errors.length" class="gl-mt-3 gl-mb-0">
        <li v-for="error in errors" :key="error" v-safe-html="error"></li>
      </ul>
    </gl-alert>

    <template v-if="isLoadingProfiles">
      <gl-skeleton-loader :width="1248" :height="180">
        <rect x="0" y="0" width="100" height="15" rx="4" />
        <rect x="0" y="24" width="460" height="32" rx="4" />
        <rect x="0" y="71" width="100" height="15" rx="4" />
        <rect x="0" y="95" width="460" height="72" rx="4" />
      </gl-skeleton-loader>
      <gl-card v-for="i in 2" :key="i" class="gl-mb-5">
        <template #header>
          <gl-skeleton-loader :width="1248" :height="15">
            <rect x="0" y="0" width="300" height="15" rx="4" />
          </gl-skeleton-loader>
        </template>
        <gl-skeleton-loader :width="1248" :height="15">
          <rect x="0" y="0" width="600" height="15" rx="4" />
        </gl-skeleton-loader>
        <gl-skeleton-loader :width="1248" :height="15">
          <rect x="0" y="0" width="300" height="15" rx="4" />
        </gl-skeleton-loader>
      </gl-card>
    </template>
    <template v-else-if="!failedToLoadProfiles">
      <gl-form-group
        :label="s__('OnDemandScans|Scan name')"
        :invalid-feedback="form.fields.name.feedback"
      >
        <gl-form-input
          v-model="form.fields.name.value"
          v-validation:[form.showValidation]
          class="mw-460"
          data-testid="dast-scan-name-input"
          type="text"
          :placeholder="s__('OnDemandScans|My daily scan')"
          :state="form.fields.name.state"
          name="name"
          required
        />
      </gl-form-group>
      <gl-form-group :label="s__('OnDemandScans|Description (optional)')">
        <gl-form-textarea
          v-model="form.fields.description.value"
          class="mw-460"
          data-testid="dast-scan-description-input"
          :placeholder="s__(`OnDemandScans|For example: Tests the login page for SQL injections`)"
          :state="form.fields.description.state"
        />
      </gl-form-group>

      <gl-form-group :label="__('Branch')">
        <ref-selector
          v-model="selectedBranch"
          data-testid="dast-scan-branch-input"
          no-flip
          :enabled-ref-types="$options.enabledRefTypes"
          :project-id="projectPath"
          :translations="{
            dropdownHeader: __('Select a branch'),
            searchPlaceholder: __('Search'),
            noRefSelected: __('No available branches'),
            noResults: __('No available branches'),
          }"
        />
        <div v-if="!defaultBranch" class="gl-text-red-500 gl-mt-3">
          {{
            s__(
              'OnDemandScans|You must create a repository within your project to run an on-demand scan.',
            )
          }}
        </div>
      </gl-form-group>

      <scanner-profile-selector
        v-model="selectedScannerProfileId"
        class="gl-mb-5"
        :profiles="scannerProfiles"
      >
        <template v-if="selectedScannerProfile" #summary>
          <div class="row">
            <profile-selector-summary-cell
              :class="{ 'gl-text-red-500': hasProfilesConflict }"
              :label="s__('DastProfiles|Scan mode')"
              :value="$options.SCAN_TYPE_LABEL[selectedScannerProfile.scanType]"
            />
          </div>
          <div class="row">
            <profile-selector-summary-cell
              :label="s__('DastProfiles|Spider timeout')"
              :value="n__('%d minute', '%d minutes', selectedScannerProfile.spiderTimeout || 0)"
            />
            <profile-selector-summary-cell
              :label="s__('DastProfiles|Target timeout')"
              :value="n__('%d second', '%d seconds', selectedScannerProfile.targetTimeout || 0)"
            />
          </div>
          <div class="row">
            <profile-selector-summary-cell
              :label="s__('DastProfiles|AJAX spider')"
              :value="selectedScannerProfile.useAjaxSpider ? __('On') : __('Off')"
            />
            <profile-selector-summary-cell
              :label="s__('DastProfiles|Debug messages')"
              :value="
                selectedScannerProfile.showDebugMessages
                  ? s__('DastProfiles|Show debug messages')
                  : s__('DastProfiles|Hide debug messages')
              "
            />
          </div>
        </template>
      </scanner-profile-selector>
      <site-profile-selector
        v-model="selectedSiteProfileId"
        class="gl-mb-5"
        :profiles="siteProfiles"
      >
        <template v-if="selectedSiteProfile" #summary>
          <div class="row">
            <profile-selector-summary-cell
              :class="{ 'gl-text-red-500': hasProfilesConflict }"
              :label="s__('DastProfiles|Target URL')"
              :value="selectedSiteProfile.targetUrl"
            />
          </div>
          <template v-if="glFeatures.securityDastSiteProfilesAdditionalFields">
            <template v-if="selectedSiteProfile.auth.enabled">
              <div class="row">
                <profile-selector-summary-cell
                  :label="s__('DastProfiles|Authentication URL')"
                  :value="selectedSiteProfile.auth.url"
                />
              </div>
              <div class="row">
                <profile-selector-summary-cell
                  :label="s__('DastProfiles|Username')"
                  :value="selectedSiteProfile.auth.username"
                />
                <profile-selector-summary-cell
                  :label="s__('DastProfiles|Password')"
                  value="••••••••"
                />
              </div>
              <div class="row">
                <profile-selector-summary-cell
                  :label="s__('DastProfiles|Username form field')"
                  :value="selectedSiteProfile.auth.usernameField"
                />
                <profile-selector-summary-cell
                  :label="s__('DastProfiles|Password form field')"
                  :value="selectedSiteProfile.auth.passwordField"
                />
              </div>
            </template>
            <div class="row">
              <profile-selector-summary-cell
                v-if="hasExcludedUrls"
                :label="s__('DastProfiles|Excluded URLs')"
                :value="selectedSiteProfile.excludedUrls.join($options.EXCLUDED_URLS_SEPARATOR)"
              />
              <profile-selector-summary-cell
                v-if="selectedSiteProfile.requestHeaders"
                :label="s__('DastProfiles|Request headers')"
                :value="__('[Redacted]')"
              />
            </div>
          </template>
        </template>
      </site-profile-selector>

      <gl-alert
        v-if="hasProfilesConflict"
        :title="s__('OnDemandScans|You cannot run an active scan against an unvalidated site.')"
        :dismissible="false"
        variant="danger"
        data-testid="on-demand-scans-profiles-conflict-alert"
      >
        <gl-sprintf
          :message="
            s__(
              'OnDemandScans|You can either choose a passive scan or validate the target site in your chosen site profile. %{docsLinkStart}Learn more about site validation.%{docsLinkEnd}',
            )
          "
        >
          <template #docsLink="{ content }">
            <gl-link :href="dastSiteValidationDocsPath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </gl-alert>

      <div class="gl-mt-6 gl-pt-6">
        <gl-button
          type="submit"
          variant="success"
          class="js-no-auto-disable"
          data-testid="on-demand-scan-submit-button"
          :disabled="isSubmitButtonDisabled"
          :loading="loading === $options.saveAndRunScanBtnId"
        >
          {{ s__('OnDemandScans|Save and run scan') }}
        </gl-button>
        <gl-button
          variant="success"
          category="secondary"
          data-testid="on-demand-scan-save-button"
          :disabled="isSaveButtonDisabled"
          :loading="loading === $options.saveScanBtnId"
          @click="onSubmit({ runAfter: false, button: $options.saveScanBtnId })"
        >
          {{ s__('OnDemandScans|Save scan') }}
        </gl-button>
        <gl-button
          data-testid="on-demand-scan-cancel-button"
          :disabled="Boolean(loading)"
          @click="onCancelClicked"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </template>
  </gl-form>
</template>
