<script>
import { GlButton, GlForm, GlFormInput, GlFormGroup, GlFormRadioGroup, GlModal } from '@gitlab/ui';
import { cloneDeep } from 'lodash';
import Vue from 'vue';
import { mapState, mapActions } from 'vuex';
import { swapArrayItems } from '~/lib/utils/array_utility';
import { sprintf } from '~/locale';
import {
  STAGE_SORT_DIRECTION,
  i18n,
  defaultCustomStageFields,
  PRESET_OPTIONS,
  PRESET_OPTIONS_DEFAULT,
} from './create_value_stream_form/constants';
import CustomStageFields from './create_value_stream_form/custom_stage_fields.vue';
import DefaultStageFields from './create_value_stream_form/default_stage_fields.vue';
import {
  validateValueStreamName,
  validateStage,
  formatStageDataForSubmission,
  hasDirtyStage,
} from './create_value_stream_form/utils';

const initializeStageErrors = (defaultStageConfig, selectedPreset = PRESET_OPTIONS_DEFAULT) =>
  selectedPreset === PRESET_OPTIONS_DEFAULT ? defaultStageConfig.map(() => ({})) : [{}];

const initializeStages = (defaultStageConfig, selectedPreset = PRESET_OPTIONS_DEFAULT) =>
  selectedPreset === PRESET_OPTIONS_DEFAULT
    ? defaultStageConfig
    : [{ ...defaultCustomStageFields }];

export default {
  name: 'ValueStreamForm',
  components: {
    GlButton,
    GlForm,
    GlFormInput,
    GlFormGroup,
    GlFormRadioGroup,
    GlModal,
    DefaultStageFields,
    CustomStageFields,
  },
  props: {
    initialData: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    initialPreset: {
      type: String,
      required: false,
      default: PRESET_OPTIONS_DEFAULT,
    },
    initialFormErrors: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    defaultStageConfig: {
      type: Array,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const {
      defaultStageConfig = [],
      initialData: { name: initialName, stages: initialStages },
      initialFormErrors,
      initialPreset,
    } = this;
    const { name: nameError = [], stages: stageErrors = [{}] } = initialFormErrors;
    const additionalFields = {
      stages: this.isEditing
        ? cloneDeep(initialStages)
        : initializeStages(defaultStageConfig, initialPreset),
      stageErrors:
        cloneDeep(stageErrors) || initializeStageErrors(defaultStageConfig, initialPreset),
    };
    return {
      hiddenStages: [],
      selectedPreset: initialPreset,
      presetOptions: PRESET_OPTIONS,
      name: initialName,
      nameError,
      stageErrors,
      ...additionalFields,
    };
  },
  computed: {
    ...mapState({ isCreating: 'isCreatingValueStream' }),
    ...mapState('customStages', ['formEvents']),
    isValueStreamNameValid() {
      return !this.nameError?.length;
    },
    invalidNameFeedback() {
      return this.nameError?.length ? this.nameError.join('\n\n') : null;
    },
    hasInitialFormErrors() {
      const { initialFormErrors } = this;
      return Boolean(Object.keys(initialFormErrors).length);
    },
    isLoading() {
      return this.isCreating;
    },
    formTitle() {
      return this.isEditing ? this.$options.i18n.EDIT_FORM_TITLE : this.$options.i18n.FORM_TITLE;
    },
    primaryProps() {
      return {
        text: this.isEditing ? this.$options.i18n.EDIT_FORM_ACTION : this.$options.i18n.FORM_TITLE,
        attributes: [{ variant: 'success' }, { loading: this.isLoading }],
      };
    },
    secondaryProps() {
      return {
        text: this.$options.i18n.BTN_ADD_ANOTHER_STAGE,
        attributes: [{ category: 'secondary' }, { variant: 'info' }, { class: '' }],
      };
    },
    hasFormErrors() {
      return Boolean(
        this.nameError.length || this.stageErrors.some((obj) => Object.keys(obj).length),
      );
    },
    isDirtyEditing() {
      return (
        this.isEditing &&
        (this.hasDirtyName(this.name, this.initialData.name) ||
          hasDirtyStage(this.stages, this.initialData.stages))
      );
    },
    canRestore() {
      return this.hiddenStages.length || this.isDirtyEditing;
    },
  },
  methods: {
    ...mapActions(['createValueStream', 'updateValueStream']),
    onSubmit() {
      this.validate();
      if (this.hasFormErrors) return false;

      let req = this.createValueStream;
      let params = {
        name: this.name,
        stages: formatStageDataForSubmission(this.stages, this.isEditing),
      };
      if (this.isEditing) {
        req = this.updateValueStream;
        params = {
          ...params,
          id: this.initialData.id,
        };
      }

      return req(params).then(() => {
        if (!this.hasInitialFormErrors) {
          const msg = this.isEditing
            ? this.$options.i18n.FORM_EDITED
            : this.$options.i18n.FORM_CREATED;
          this.$toast.show(sprintf(msg, { name: this.name }), {
            position: 'top-center',
          });
          this.name = '';
          this.nameError = [];
          this.stages = initializeStages(this.defaultStageConfig, this.selectedPreset);
          this.stageErrors = initializeStageErrors(this.defaultStageConfig, this.selectedPreset);
        }
      });
    },
    stageKey(index) {
      return this.selectedPreset === PRESET_OPTIONS_DEFAULT
        ? `default-template-stage-${index}`
        : `custom-template-stage-${index}`;
    },
    stageGroupLabel(index) {
      return sprintf(this.$options.i18n.STAGE_INDEX, { index: index + 1 });
    },
    recoverStageTitle(name) {
      return sprintf(this.$options.i18n.HIDDEN_DEFAULT_STAGE, { name });
    },
    hasDirtyName(current, original) {
      return current.trim().toLowerCase() !== original.trim().toLowerCase();
    },
    validateStages() {
      return this.stages.map(validateStage);
    },
    validate() {
      const { name } = this;
      Vue.set(this, 'nameError', validateValueStreamName({ name }));
      Vue.set(this, 'stageErrors', this.validateStages());
    },
    moveItem(arr, index, direction) {
      return direction === STAGE_SORT_DIRECTION.UP
        ? swapArrayItems(arr, index - 1, index)
        : swapArrayItems(arr, index, index + 1);
    },
    handleMove({ index, direction }) {
      const newStages = this.moveItem(this.stages, index, direction);
      const newErrors = this.moveItem(this.stageErrors, index, direction);
      Vue.set(this, 'stageErrors', cloneDeep(newErrors));
      Vue.set(this, 'stages', cloneDeep(newStages));
    },
    validateStageFields(index) {
      Vue.set(this.stageErrors, index, validateStage(this.stages[index]));
    },
    fieldErrors(index) {
      return this.stageErrors && this.stageErrors[index] ? this.stageErrors[index] : {};
    },
    onHide(index) {
      const target = this.stages[index];
      Vue.set(this, 'stages', [...this.stages.filter((_, i) => i !== index)]);
      Vue.set(this, 'hiddenStages', [...this.hiddenStages, target]);
    },
    onRemove(index) {
      const newErrors = this.stageErrors.filter((_, idx) => idx !== index);
      const newStages = this.stages.filter((_, idx) => idx !== index);
      Vue.set(this, 'stages', [...newStages]);
      Vue.set(this, 'stageErrors', [...newErrors]);
    },
    onRestore(hiddenStageIndex) {
      const target = this.hiddenStages[hiddenStageIndex];
      Vue.set(this, 'hiddenStages', [
        ...this.hiddenStages.filter((_, i) => i !== hiddenStageIndex),
      ]);
      Vue.set(this, 'stages', [...this.stages, target]);
    },
    lastStage() {
      const stages = this.$refs.formStages;
      return stages[stages.length - 1];
    },
    async scrollToLastStage() {
      await this.$nextTick();
      // Scroll to the new stage we have added
      this.lastStage().focus();
      this.lastStage().scrollIntoView({ behavior: 'smooth' });
    },
    addNewStage() {
      // validate previous stages only and add a new stage
      this.validate();
      Vue.set(this, 'stages', [...this.stages, { ...defaultCustomStageFields }]);
      Vue.set(this, 'stageErrors', [...this.stageErrors, {}]);
    },
    onAddStage() {
      this.addNewStage();
      this.scrollToLastStage();
    },
    onFieldInput(activeStageIndex, { field, value }) {
      const updatedStage = { ...this.stages[activeStageIndex], [field]: value };
      Vue.set(this.stages, activeStageIndex, updatedStage);
    },
    handleResetDefaults() {
      if (this.isEditing) {
        const {
          initialData: { name: initialName, stages: initialStages },
        } = this;
        Vue.set(this, 'name', initialName);
        Vue.set(this, 'nameError', []);
        Vue.set(this, 'stages', cloneDeep(initialStages));
        Vue.set(this, 'stageErrors', [{}]);
      } else {
        this.name = '';
        this.defaultStageConfig.forEach((stage, index) => {
          Vue.set(this.stages, index, { ...stage, hidden: false });
        });
      }
    },
    handleResetBlank() {
      this.name = '';
      Vue.set(this, 'stages', [{ ...defaultCustomStageFields }]);
    },
    onSelectPreset() {
      if (this.selectedPreset === PRESET_OPTIONS_DEFAULT) {
        this.handleResetDefaults();
      } else {
        this.handleResetBlank();
      }
      Vue.set(
        this,
        'stageErrors',
        initializeStageErrors(this.defaultStageConfig, this.selectedPreset),
      );
    },
  },
  i18n,
};
</script>
<template>
  <gl-modal
    data-testid="value-stream-form-modal"
    modal-id="value-stream-form-modal"
    dialog-class="gl-align-items-flex-start! gl-py-7"
    scrollable
    :title="formTitle"
    :action-primary="primaryProps"
    :action-secondary="secondaryProps"
    :action-cancel="{ text: $options.i18n.BTN_CANCEL }"
    @hidden.prevent="$emit('hidden')"
    @secondary.prevent="onAddStage"
    @primary.prevent="onSubmit"
  >
    <gl-form>
      <gl-form-group
        data-testid="create-value-stream-name"
        label-for="create-value-stream-name"
        :label="$options.i18n.FORM_FIELD_NAME_LABEL"
        :invalid-feedback="invalidNameFeedback"
        :state="isValueStreamNameValid"
      >
        <div class="gl-display-flex gl-justify-content-space-between">
          <gl-form-input
            id="create-value-stream-name"
            v-model.trim="name"
            name="create-value-stream-name"
            :placeholder="$options.i18n.FORM_FIELD_NAME_PLACEHOLDER"
            :state="isValueStreamNameValid"
            required
          />
          <transition name="fade">
            <gl-button
              v-if="canRestore"
              class="gl-ml-3"
              variant="link"
              @click="handleResetDefaults"
              >{{ $options.i18n.RESTORE_DEFAULTS }}</gl-button
            >
          </transition>
        </div>
      </gl-form-group>
      <gl-form-radio-group
        v-if="!isEditing"
        v-model="selectedPreset"
        class="gl-mb-4"
        data-testid="vsa-preset-selector"
        :options="presetOptions"
        name="preset"
        @input="onSelectPreset"
      />
      <div data-testid="extended-form-fields">
        <div
          v-for="(stage, activeStageIndex) in stages"
          ref="formStages"
          :key="stageKey(activeStageIndex)"
        >
          <hr class="gl-my-3" />
          <span
            class="gl-display-flex gl-m-0 gl-vertical-align-middle gl-mr-2 gl-font-weight-bold gl-display-flex gl-pb-3"
            >{{ stageGroupLabel(activeStageIndex) }}</span
          >
          <custom-stage-fields
            v-if="stage.custom"
            :stage="stage"
            :stage-events="formEvents"
            :index="activeStageIndex"
            :total-stages="stages.length"
            :errors="fieldErrors(activeStageIndex)"
            @move="handleMove"
            @remove="onRemove"
            @input="onFieldInput(activeStageIndex, $event)"
          />
          <default-stage-fields
            v-else
            :stage="stage"
            :stage-events="formEvents"
            :index="activeStageIndex"
            :total-stages="stages.length"
            :errors="fieldErrors(activeStageIndex)"
            @move="handleMove"
            @hide="onHide"
            @input="validateStageFields(activeStageIndex)"
          />
        </div>
        <div v-if="hiddenStages.length">
          <hr />
          <gl-form-group v-for="(stage, hiddenStageIndex) in hiddenStages" :key="stage.id">
            <span class="gl-m-0 gl-vertical-align-middle gl-mr-3 gl-font-weight-bold">{{
              recoverStageTitle(stage.name)
            }}</span>
            <gl-button variant="link" @click="onRestore(hiddenStageIndex)">{{
              $options.i18n.RESTORE_HIDDEN_STAGE
            }}</gl-button>
          </gl-form-group>
        </div>
      </div>
    </gl-form>
  </gl-modal>
</template>
