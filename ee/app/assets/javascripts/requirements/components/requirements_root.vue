<script>
import { GlPagination, GlAlert } from '@gitlab/ui';
import Api from '~/api';
import createFlash, { FLASH_TYPES } from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { urlParamsToObject } from '~/lib/utils/common_utils';
import { updateHistory, setUrlParams } from '~/lib/utils/url_utility';
import { __, sprintf } from '~/locale';
import Tracking from '~/tracking';

import { DEFAULT_LABEL_ANY } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import AuthorToken from '~/vue_shared/components/filtered_search_bar/tokens/author_token.vue';

import {
  FilterState,
  AvailableSortOptions,
  TestReportStatus,
  TestReportStatusToValue,
  DEFAULT_PAGE_SIZE,
} from '../constants';
import createRequirement from '../queries/createRequirement.mutation.graphql';
import exportRequirement from '../queries/exportRequirements.mutation.graphql';
import projectRequirements from '../queries/projectRequirements.query.graphql';
import projectRequirementsCount from '../queries/projectRequirementsCount.query.graphql';
import updateRequirement from '../queries/updateRequirement.mutation.graphql';
import ExportRequirementsModal from './export_requirements_modal.vue';
import ImportRequirementsModal from './import_requirements_modal.vue';
import RequirementForm from './requirement_form.vue';
import RequirementItem from './requirement_item.vue';
import RequirementsEmptyState from './requirements_empty_state.vue';
import RequirementsLoading from './requirements_loading.vue';
import RequirementsTabs from './requirements_tabs.vue';

import StatusToken from './tokens/status_token.vue';

export default {
  DEFAULT_PAGE_SIZE,
  AvailableSortOptions,
  components: {
    GlPagination,
    GlAlert,
    FilteredSearchBar,
    RequirementsTabs,
    RequirementsLoading,
    RequirementsEmptyState,
    RequirementItem,
    RequirementCreateForm: RequirementForm,
    RequirementEditForm: RequirementForm,
    ImportRequirementsModal,
    ExportRequirementsModal,
  },
  mixins: [Tracking.mixin()],
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    initialFilterBy: {
      type: String,
      required: true,
    },
    initialTextSearch: {
      type: String,
      required: false,
      default: '',
    },
    initialSortBy: {
      type: String,
      required: false,
      default: 'created_desc',
    },
    initialAuthorUsernames: {
      type: Array,
      required: false,
      default: () => [],
    },
    initialStatus: {
      type: String,
      required: false,
      default: '',
    },
    initialRequirementsCount: {
      type: Object,
      required: true,
      validator: (value) =>
        ['OPENED', 'ARCHIVED', 'ALL'].every((prop) => typeof value[prop] === 'number'),
    },
    page: {
      type: Number,
      required: false,
      default: 1,
    },
    prev: {
      type: String,
      required: false,
      default: '',
    },
    next: {
      type: String,
      required: false,
      default: '',
    },
    emptyStatePath: {
      type: String,
      required: true,
    },
    canCreateRequirement: {
      type: Boolean,
      required: true,
    },
    requirementsWebUrl: {
      type: String,
      required: true,
    },
    importCsvPath: {
      type: String,
      required: true,
    },
    currentUserEmail: {
      type: String,
      required: true,
    },
  },
  apollo: {
    requirements: {
      query: projectRequirements,
      variables() {
        const queryVariables = {
          projectPath: this.projectPath,
        };

        if (this.prevPageCursor) {
          queryVariables.prevPageCursor = this.prevPageCursor;
          queryVariables.lastPageSize = DEFAULT_PAGE_SIZE;
        } else if (this.nextPageCursor) {
          queryVariables.nextPageCursor = this.nextPageCursor;
          queryVariables.firstPageSize = DEFAULT_PAGE_SIZE;
        } else {
          queryVariables.firstPageSize = DEFAULT_PAGE_SIZE;
        }

        // Include `state` only if `filterBy` is not `ALL`.
        // as Grqph query only supports `OPEN` and `ARCHIVED`.
        if (this.filterBy !== FilterState.all) {
          queryVariables.state = this.filterBy;
        }

        if (this.textSearch) {
          queryVariables.search = this.textSearch;
        }

        if (this.authorUsernames.length) {
          queryVariables.authorUsernames = this.authorUsernames;
        }

        if (this.status) {
          queryVariables.status = TestReportStatusToValue[this.status];
        }

        if (this.sortBy) {
          queryVariables.sortBy = this.sortBy;
        }

        return queryVariables;
      },
      update(data) {
        const requirementsRoot = data.project?.requirements;

        const list = requirementsRoot?.nodes.map((node) => {
          return {
            ...node,
            satisfied: node.lastTestReportState === TestReportStatus.Passed,
          };
        });

        return {
          list: list || [],
          pageInfo: requirementsRoot?.pageInfo || {},
        };
      },
      error() {
        createFlash({
          message: __('Something went wrong while fetching requirements list.'),
          captureError: true,
        });
      },
    },
    requirementsCount: {
      query: projectRequirementsCount,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update({ project = {} }) {
        const { opened = 0, archived = 0 } = project.requirementStatesCount;

        return {
          OPENED: opened,
          ARCHIVED: archived,
          ALL: opened + archived,
        };
      },
      error() {
        createFlash({
          message: __('Something went wrong while fetching requirements count.'),
          captureError: true,
        });
      },
    },
  },
  data() {
    return {
      filterBy: this.initialFilterBy,
      textSearch: this.initialTextSearch,
      authorUsernames: this.initialAuthorUsernames,
      status: this.initialStatus,
      sortBy: this.initialSortBy,
      showRequirementCreateDrawer: false,
      showRequirementViewDrawer: false,
      enableRequirementEdit: false,
      editedRequirement: null,
      createRequirementRequestActive: false,
      stateChangeRequestActiveFor: 0,
      currentPage: this.page,
      prevPageCursor: this.prev,
      nextPageCursor: this.next,
      requirements: {
        list: [],
        pageInfo: {},
      },
      requirementsCount: {
        OPENED: this.initialRequirementsCount[FilterState.opened],
        ARCHIVED: this.initialRequirementsCount[FilterState.archived],
        ALL: this.initialRequirementsCount[FilterState.all],
      },
      alert: null,
    };
  },
  computed: {
    requirementsList() {
      return this.filterBy !== FilterState.all
        ? this.requirements.list.filter(({ state }) => state === this.filterBy)
        : this.requirements.list;
    },
    requirementsListLoading() {
      return this.$apollo.queries.requirements.loading;
    },
    requirementsListEmpty() {
      return !this.$apollo.queries.requirements.loading && !this.requirementsList.length;
    },
    totalRequirementsForCurrentTab() {
      return this.requirementsCount[this.filterBy];
    },
    showEmptyState() {
      return this.requirementsListEmpty && !this.showRequirementCreateDrawer;
    },
    showPaginationControls() {
      const { hasPreviousPage, hasNextPage } = this.requirements.pageInfo;

      // This explicit check is necessary as both the variables
      // can also be `false` and we just want to ensure that they're present.
      if (hasPreviousPage !== undefined || hasNextPage !== undefined) {
        return Boolean(hasPreviousPage || hasNextPage);
      }
      return this.totalRequirementsForCurrentTab > DEFAULT_PAGE_SIZE && !this.requirementsListEmpty;
    },
    prevPage() {
      return Math.max(this.currentPage - 1, 0);
    },
    nextPage() {
      const nextPage = this.currentPage + 1;
      return nextPage > Math.ceil(this.totalRequirementsForCurrentTab / DEFAULT_PAGE_SIZE)
        ? null
        : nextPage;
    },
  },
  methods: {
    getFilteredSearchTokens() {
      return [
        {
          type: 'author_username',
          icon: 'user',
          title: __('Author'),
          unique: false,
          symbol: '@',
          token: AuthorToken,
          operators: [{ value: '=', description: __('is'), default: 'true' }],
          fetchPath: this.projectPath,
          fetchAuthors: Api.projectUsers.bind(Api),
        },
        {
          type: 'status',
          icon: 'status',
          title: __('Status'),
          unique: true,
          token: StatusToken,
          operators: [{ value: '=', description: __('is'), default: 'true' }],
        },
      ];
    },
    getFilteredSearchValue() {
      const value = this.authorUsernames.map((author) => ({
        type: 'author_username',
        value: { data: author },
      }));

      if (this.status) {
        value.push({
          type: 'status',
          value: { data: this.status },
        });
      }

      if (this.textSearch) {
        value.push({
          type: 'filtered-search-term',
          value: { data: this.textSearch },
        });
      }

      return value;
    },
    /**
     * Update browser URL with updated query-param values
     * based on current page details.
     */
    updateUrl() {
      const { href, search } = window.location;
      const queryParams = urlParamsToObject(search);
      const {
        filterBy,
        currentPage,
        prevPageCursor,
        nextPageCursor,
        textSearch,
        authorUsernames,
        status,
        sortBy,
      } = this;

      queryParams.page = currentPage || 1;
      // Only keep params that have any values.
      if (prevPageCursor) {
        queryParams.prev = prevPageCursor;
      } else {
        delete queryParams.prev;
      }

      if (nextPageCursor) {
        queryParams.next = nextPageCursor;
      } else {
        delete queryParams.next;
      }

      if (filterBy) {
        queryParams.state = filterBy.toLowerCase();
      } else {
        delete queryParams.state;
      }

      if (textSearch) {
        queryParams.search = textSearch;
      } else {
        delete queryParams.search;
      }

      if (sortBy) {
        queryParams.sort = sortBy;
      } else {
        delete queryParams.sort;
      }

      delete queryParams.author_username;
      if (authorUsernames.length) {
        queryParams['author_username[]'] = authorUsernames;
      }

      if (status) {
        queryParams.status = status;
      } else {
        delete queryParams.status;
      }

      // We want to replace the history state so that back button
      // correctly reloads the page with previous URL.
      updateHistory({
        url: setUrlParams(queryParams, href, true),
        title: document.title,
        replace: true,
      });
    },
    updateRequirement(requirement = {}, { errorFlashMessage, flashMessageContainer } = {}) {
      const { iid, title, description, state, lastTestReportState } = requirement;
      const updateRequirementInput = {
        projectPath: this.projectPath,
        iid,
      };

      if (title) {
        updateRequirementInput.title = title;
      }
      if (description) {
        updateRequirementInput.description = description;
      }
      if (state) {
        updateRequirementInput.state = state;
      }
      if (lastTestReportState) {
        updateRequirementInput.lastTestReportState = lastTestReportState;
      }

      return this.$apollo
        .mutate({
          mutation: updateRequirement,
          variables: {
            updateRequirementInput,
          },
        })
        .catch((e) => {
          createFlash({
            message: errorFlashMessage,
            parent: flashMessageContainer,
            captureError: true,
          });
          throw e;
        });
    },
    importCsv({ file }) {
      const formData = new FormData();
      formData.append('file', file);
      return axios
        .post(this.importCsvPath, formData, {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        })
        .then(({ data }) => {
          createFlash({ message: data?.message, type: FLASH_TYPES.NOTICE });
        })
        .catch((err) => {
          const { data: { message = __('Something went wrong') } = {} } = err.response;
          createFlash({ message });
        });
    },
    exportCsv(selectedFields) {
      return this.$apollo
        .mutate({
          mutation: exportRequirement,
          variables: {
            projectPath: this.projectPath,
            state: this.filterBy,
            authorUsername: this.authorUsernames,
            search: this.textSearch,
            sortBy: this.sortBy,
            selectedFields,
          },
        })
        .then(() => {
          this.alert = {
            variant: 'info',
            message: sprintf(
              __('Your CSV export has started. It will be emailed to %{email} when complete.'),
              { email: this.currentUserEmail },
            ),
          };
        })
        .catch((e) => {
          createFlash({
            message: __('Something went wrong while exporting requirements'),
            captureError: true,
            error: e,
          });
          throw e;
        });
    },
    handleTabClick({ filterBy }) {
      this.filterBy = filterBy;
      this.prevPageCursor = '';
      this.nextPageCursor = '';

      // Update browser URL
      updateHistory({
        url: setUrlParams({ state: filterBy.toLowerCase() }, window.location.href, true),
        title: document.title,
        replace: true,
      });

      // Wait for changes to propagate in component
      // and then fetch again.
      this.$nextTick(() => this.$apollo.queries.requirements.refetch());
    },
    handleNewRequirementClick() {
      this.showRequirementCreateDrawer = true;
    },
    handleShowRequirementClick(requirement) {
      this.showRequirementViewDrawer = true;
      this.editedRequirement = requirement;
    },
    handleEditRequirementClick(requirement) {
      this.showRequirementViewDrawer = true;
      this.enableRequirementEdit = true;
      this.editedRequirement = requirement;
    },
    handleNewRequirementSave({ title, description }) {
      this.createRequirementRequestActive = true;
      return this.$apollo
        .mutate({
          mutation: createRequirement,
          variables: {
            createRequirementInput: {
              projectPath: this.projectPath,
              title,
              description,
            },
          },
        })
        .then((res) => {
          const createReqMutation = res?.data?.createRequirement || {};

          if (createReqMutation.errors?.length === 0) {
            this.$apollo.queries.requirementsCount.refetch();
            this.$apollo.queries.requirements.refetch();
            this.$toast.show(
              sprintf(__('Requirement %{reference} has been added'), {
                reference: `REQ-${createReqMutation.requirement.iid}`,
              }),
            );
            this.showRequirementCreateDrawer = false;
          } else {
            throw new Error(`Error creating a requirement ${res.message}`);
          }
        })
        .catch((e) => {
          createFlash({
            message: __('Something went wrong while creating a requirement.'),
            parent: this.$el,
            captureError: true,
          });
          throw new Error(`Error creating a requirement ${e.message}`);
        })
        .finally(() => {
          this.createRequirementRequestActive = false;
        });
    },
    handleRequirementEdit(enableRequirementEdit) {
      this.enableRequirementEdit = enableRequirementEdit;
    },
    handleNewRequirementCancel() {
      this.showRequirementCreateDrawer = false;
    },
    handleUpdateRequirementSave(requirement) {
      this.createRequirementRequestActive = true;
      return this.updateRequirement(requirement, {
        errorFlashMessage: __('Something went wrong while updating a requirement.'),
        flashMessageContainer: this.$el,
      })
        .then((res) => {
          const updateReqMutation = res?.data?.updateRequirement || {};

          if (updateReqMutation.errors?.length === 0) {
            this.enableRequirementEdit = false;
            this.editedRequirement = updateReqMutation.requirement;
            this.$toast.show(
              sprintf(__('Requirement %{reference} has been updated'), {
                reference: `REQ-${this.editedRequirement.iid}`,
              }),
            );
          } else {
            throw new Error(`Error updating a requirement ${res.message}`);
          }
        })
        .finally(() => {
          this.createRequirementRequestActive = false;
        });
    },
    handleRequirementStateChange(requirement) {
      this.stateChangeRequestActiveFor = requirement.iid;
      return this.updateRequirement(requirement, {
        errorFlashMessage:
          requirement.state === FilterState.opened
            ? __('Something went wrong while reopening a requirement.')
            : __('Something went wrong while archiving a requirement.'),
      })
        .then((res) => {
          const updateReqMutation = res?.data?.updateRequirement || {};

          if (updateReqMutation.errors?.length === 0) {
            this.$apollo.queries.requirementsCount.refetch();
            const reference = `REQ-${updateReqMutation.requirement.iid}`;
            let toastMessage;
            if (requirement.state === FilterState.opened) {
              toastMessage = sprintf(__('Requirement %{reference} has been reopened'), {
                reference,
              });
            } else {
              toastMessage = sprintf(__('Requirement %{reference} has been archived'), {
                reference,
              });
            }
            this.$toast.show(toastMessage);
          } else {
            throw new Error(`Error archiving a requirement ${res.message}`);
          }
        })
        .finally(() => {
          this.stateChangeRequestActiveFor = 0;
        });
    },
    handleUpdateRequirementDrawerClose() {
      this.enableRequirementEdit = false;
      this.showRequirementViewDrawer = false;
      this.editedRequirement = null;
    },
    handleFilterRequirements(filters = []) {
      const authors = [];
      let status = '';
      const textSearch = [];

      filters.forEach((filter) => {
        switch (filter.type) {
          case 'author_username':
            if (filter.value.data !== DEFAULT_LABEL_ANY.value) {
              authors.push(filter.value.data);
            }
            break;
          case 'status':
            status = filter.value.data;
            break;
          case 'filtered-search-term':
            if (filter.value.data) textSearch.push(filter.value.data);
            break;
          default:
            break;
        }
      });

      this.authorUsernames = [...authors];
      this.status = status;
      this.textSearch = textSearch.join(' ');
      this.currentPage = 1;
      this.prevPageCursor = '';
      this.nextPageCursor = '';

      if (textSearch.length || authors.length || status) {
        this.track('filter', {
          property: JSON.stringify(filters),
        });
      }

      this.updateUrl();
    },
    handleSortRequirements(sortBy) {
      this.sortBy = sortBy;

      this.currentPage = 1;
      this.prevPageCursor = '';
      this.nextPageCursor = '';
      this.updateUrl();
    },
    handlePageChange(page) {
      const { startCursor, endCursor } = this.requirements.pageInfo;
      const toNext = page > this.currentPage;

      if (toNext) {
        this.prevPageCursor = '';
        this.nextPageCursor = endCursor;
      } else {
        this.prevPageCursor = startCursor;
        this.nextPageCursor = '';
      }

      this.track('click_navigation', { label: toNext ? 'next' : 'prev' });

      this.currentPage = page;

      this.updateUrl();
    },
    handleImportRequirementsClick() {
      this.$refs.modal.show();
    },
  },
};
</script>

<template>
  <div class="requirements-list-container">
    <gl-alert
      v-if="alert"
      :variant="alert.variant"
      :dismissible="true"
      class="gl-mt-3 gl-mb-4"
      @dismiss="alert = null"
    >
      {{ alert.message }}
    </gl-alert>

    <requirements-tabs
      :filter-by="filterBy"
      :requirements-count="requirementsCount"
      :show-create-form="showRequirementCreateDrawer"
      :can-create-requirement="canCreateRequirement"
      @click-tab="handleTabClick"
      @click-new-requirement="handleNewRequirementClick"
      @click-import-requirements="handleImportRequirementsClick"
      @click-export-requirements="$refs.exportModal.show()"
    />
    <filtered-search-bar
      :namespace="projectPath"
      :search-input-placeholder="__('Search requirements')"
      :tokens="getFilteredSearchTokens()"
      :sort-options="$options.AvailableSortOptions"
      :initial-filter-value="getFilteredSearchValue()"
      :initial-sort-by="sortBy"
      recent-searches-storage-key="requirements"
      class="row-content-block"
      @onFilter="handleFilterRequirements"
      @onSort="handleSortRequirements"
    />
    <requirement-create-form
      :drawer-open="showRequirementCreateDrawer"
      :requirement-request-active="createRequirementRequestActive"
      @save="handleNewRequirementSave"
      @drawer-close="handleNewRequirementCancel"
    />
    <requirement-edit-form
      data-testid="edit-form"
      :drawer-open="showRequirementViewDrawer"
      :requirement="editedRequirement"
      :enable-requirement-edit="enableRequirementEdit"
      :requirement-request-active="createRequirementRequestActive"
      @save="handleUpdateRequirementSave"
      @enable-edit="handleRequirementEdit(true)"
      @disable-edit="handleRequirementEdit(false)"
      @drawer-close="handleUpdateRequirementDrawerClose"
    />
    <requirements-empty-state
      v-if="showEmptyState"
      :filter-by="filterBy"
      :empty-state-path="emptyStatePath"
      :requirements-count="requirementsCount"
      :can-create-requirement="canCreateRequirement"
      @click-new-requirement="handleNewRequirementClick"
      @click-import-requirements="handleImportRequirementsClick"
    />
    <requirements-loading
      v-show="requirementsListLoading"
      :filter-by="filterBy"
      :current-page="currentPage"
      :requirements-count="requirementsCount"
    />
    <ul
      v-if="!requirementsListLoading && !requirementsListEmpty"
      class="content-list issuable-list issues-list requirements-list"
    >
      <requirement-item
        v-for="requirement in requirementsList"
        :key="requirement.iid"
        :requirement="requirement"
        :state-change-request-active="stateChangeRequestActiveFor === requirement.iid"
        :active="editedRequirement && editedRequirement.iid === requirement.iid"
        @show-click="handleShowRequirementClick"
        @edit-click="handleEditRequirementClick"
        @archiveClick="handleRequirementStateChange"
        @reopenClick="handleRequirementStateChange"
      />
    </ul>
    <gl-pagination
      v-if="showPaginationControls"
      :value="currentPage"
      :per-page="$options.DEFAULT_PAGE_SIZE"
      :prev-page="prevPage"
      :next-page="nextPage"
      align="center"
      class="gl-pagination gl-mt-3"
      @input="handlePageChange"
    />
    <import-requirements-modal ref="modal" :project-path="projectPath" @import="importCsv" />
    <export-requirements-modal
      ref="exportModal"
      :requirement-count="totalRequirementsForCurrentTab"
      :email="currentUserEmail"
      @export="exportCsv"
    />
  </div>
</template>
