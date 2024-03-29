<script>
import { GlModal, GlAlert } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { s__, __ } from '~/locale';
import createOncallScheduleMutation from '../graphql/mutations/create_oncall_schedule.mutation.graphql';
import updateOncallScheduleMutation from '../graphql/mutations/update_oncall_schedule.mutation.graphql';
import getOncallSchedulesWithRotationsQuery from '../graphql/queries/get_oncall_schedules.query.graphql';
import { updateStoreOnScheduleCreate, updateStoreAfterScheduleEdit } from '../utils/cache_updates';
import { isNameFieldValid } from '../utils/common_utils';
import AddEditScheduleForm from './add_edit_schedule_form.vue';

export const i18n = {
  cancel: __('Cancel'),
  addSchedule: s__('OnCallSchedules|Add schedule'),
  editSchedule: s__('OnCallSchedules|Edit schedule'),
  addErrorMsg: s__('OnCallSchedules|Failed to edit schedule'),
  editErrorMsg: s__('OnCallSchedules|Failed to add schedule'),
};

export default {
  i18n,
  components: {
    GlModal,
    GlAlert,
    AddEditScheduleForm,
  },
  inject: ['projectPath', 'timezones'],
  props: {
    modalId: {
      type: String,
      required: true,
    },
    schedule: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isEditMode: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      loading: false,
      form: {
        name: this.schedule?.name,
        description: this.schedule?.description,
        timezone: this.timezones.find(({ identifier }) => this.schedule?.timezone === identifier),
      },
      error: '',
      validationState: {
        name: true,
        timezone: true,
      },
    };
  },
  computed: {
    actionsProps() {
      return {
        primary: {
          text: this.title,
          attributes: [
            { variant: 'info' },
            { loading: this.loading },
            { disabled: !this.isFormValid },
          ],
        },
        cancel: {
          text: i18n.cancel,
        },
      };
    },
    isFormValid() {
      return Object.values(this.validationState).every(Boolean);
    },
    editScheduleVariables() {
      return {
        projectPath: this.projectPath,
        iid: this.schedule.iid,
        name: this.form.name,
        description: this.form.description,
        timezone: this.form.timezone.identifier,
      };
    },
    errorMsg() {
      return this.error || (this.isEditMode ? i18n.editErrorMsg : i18n.addErrorMsg);
    },
    title() {
      return this.isEditMode ? i18n.editSchedule : i18n.addSchedule;
    },
  },
  methods: {
    createSchedule() {
      this.loading = true;
      const { projectPath } = this;

      this.$apollo
        .mutate({
          mutation: createOncallScheduleMutation,
          variables: {
            oncallScheduleCreateInput: {
              projectPath,
              ...this.form,
              timezone: this.form.timezone.identifier,
            },
          },
          update(store, { data }) {
            updateStoreOnScheduleCreate(store, getOncallSchedulesWithRotationsQuery, data, {
              projectPath,
            });
          },
        })
        .then(
          ({
            data: {
              oncallScheduleCreate: {
                errors: [error],
              },
            },
          }) => {
            if (error) {
              throw error;
            }
            this.$refs.addUpdateScheduleModal.hide();
            this.$emit('scheduleCreated');
          },
        )
        .catch((error) => {
          this.error = error;
        })
        .finally(() => {
          this.loading = false;
        });
    },
    editSchedule() {
      const {
        projectPath,
        form: { timezone },
      } = this;
      this.loading = true;

      this.$apollo
        .mutate({
          mutation: updateOncallScheduleMutation,
          variables: this.editScheduleVariables,
          update(store, { data }) {
            updateStoreAfterScheduleEdit(store, getOncallSchedulesWithRotationsQuery, data, {
              projectPath,
            });
          },
        })
        .then(
          ({
            data: {
              oncallScheduleUpdate: {
                errors: [error],
              },
            },
          }) => {
            if (error) {
              throw error;
            }
            this.$refs.addUpdateScheduleModal.hide();
          },
        )
        .catch((error) => {
          this.error = error;
        })
        .finally(() => {
          this.loading = false;
          if (timezone !== this.schedule.timezone) {
            window.location.reload();
          }
        });
    },
    hideErrorAlert() {
      this.error = '';
    },
    updateScheduleForm({ type, value }) {
      this.form[type] = value;
      this.validateForm(type);
    },
    validateForm(key) {
      if (key === 'name') {
        this.validationState.name = isNameFieldValid(this.form.name);
      } else if (key === 'timezone') {
        this.validationState.timezone = !isEmpty(this.form.timezone);
      }
    },
  },
};
</script>

<template>
  <gl-modal
    ref="addUpdateScheduleModal"
    :modal-id="modalId"
    size="sm"
    :title="title"
    :action-primary="actionsProps.primary"
    :action-cancel="actionsProps.cancel"
    @primary.prevent="isEditMode ? editSchedule() : createSchedule()"
  >
    <gl-alert v-if="error" variant="danger" class="gl-mt-n3 gl-mb-3" @dismiss="hideErrorAlert">
      {{ errorMsg }}
    </gl-alert>
    <add-edit-schedule-form
      :validation-state="validationState"
      :form="form"
      :schedule="schedule"
      @update-schedule-form="updateScheduleForm"
    />
  </gl-modal>
</template>
