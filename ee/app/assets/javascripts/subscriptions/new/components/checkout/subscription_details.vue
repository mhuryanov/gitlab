<script>
import { GlFormGroup, GlFormSelect, GlFormInput, GlSprintf, GlLink } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { mapState, mapGetters, mapActions } from 'vuex';
import { NEW_GROUP, STEPS } from 'ee/subscriptions/new/constants';
import Step from 'ee/vue_shared/purchase_flow/components/step.vue';
import { sprintf, s__ } from '~/locale';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';

export default {
  components: {
    GlFormGroup,
    GlFormSelect,
    GlFormInput,
    GlSprintf,
    GlLink,
    Step,
  },
  directives: {
    autofocusonshow,
  },
  computed: {
    ...mapState([
      'availablePlans',
      'selectedPlan',
      'isNewUser',
      'groupData',
      'selectedGroup',
      'isSetupForCompany',
      'organizationName',
      'numberOfUsers',
    ]),
    ...mapGetters([
      'selectedPlanText',
      'isGroupSelected',
      'selectedGroupUsers',
      'selectedGroupName',
    ]),
    selectedPlanModel: {
      get() {
        return this.selectedPlan;
      },
      set(selectedPlan) {
        this.updateSelectedPlan(selectedPlan);
      },
    },
    selectedGroupModel: {
      get() {
        return this.selectedGroup;
      },
      set(selectedGroup) {
        this.updateSelectedGroup(selectedGroup);
      },
    },
    numberOfUsersModel: {
      get() {
        return this.numberOfUsers;
      },
      set(number) {
        this.updateNumberOfUsers(number);
      },
    },
    organizationNameModel: {
      get() {
        return this.organizationName;
      },
      set(organizationName) {
        this.updateOrganizationName(organizationName);
      },
    },
    selectedPlanTextLine() {
      return sprintf(this.$options.i18n.selectedPlan, { selectedPlanText: this.selectedPlanText });
    },
    isValid() {
      if (this.isSetupForCompany) {
        return (
          !isEmpty(this.selectedPlan) &&
          (!isEmpty(this.organizationName) || this.isGroupSelected) &&
          this.numberOfUsers > 0 &&
          this.numberOfUsers >= this.selectedGroupUsers
        );
      }
      return !isEmpty(this.selectedPlan) && this.numberOfUsers === 1;
    },
    isShowingGroupSelector() {
      return !this.isNewUser && this.groupData.length;
    },
    isShowingNameOfCompanyInput() {
      return this.isSetupForCompany && (!this.groupData.length || this.selectedGroup === NEW_GROUP);
    },
    groupOptionsWithDefault() {
      return [
        {
          text: this.$options.i18n.groupSelectPrompt,
          value: null,
        },
        ...this.groupData,
        {
          text: this.$options.i18n.groupSelectCreateNewOption,
          value: NEW_GROUP,
        },
      ];
    },
    groupSelectDescription() {
      return this.selectedGroup === NEW_GROUP
        ? this.$options.i18n.createNewGroupDescription
        : this.$options.i18n.selectedGroupDescription;
    },
  },
  methods: {
    ...mapActions([
      'updateSelectedPlan',
      'updateSelectedGroup',
      'toggleIsSetupForCompany',
      'updateNumberOfUsers',
      'updateOrganizationName',
    ]),
  },
  i18n: {
    stepTitle: s__('Checkout|Subscription details'),
    nextStepButtonText: s__('Checkout|Continue to billing'),
    selectedPlanLabel: s__('Checkout|GitLab plan'),
    selectedGroupLabel: s__('Checkout|GitLab group'),
    groupSelectPrompt: s__('Checkout|Select'),
    groupSelectCreateNewOption: s__('Checkout|Create a new group'),
    selectedGroupDescription: s__('Checkout|Your subscription will be applied to this group'),
    createNewGroupDescription: s__("Checkout|You'll create your new group after checkout"),
    organizationNameLabel: s__('Checkout|Name of company or organization using GitLab'),
    numberOfUsersLabel: s__('Checkout|Number of users'),
    needMoreUsersLink: s__('Checkout|Need more users? Purchase GitLab for your %{company}.'),
    companyOrTeam: s__('Checkout|company or team'),
    selectedPlan: s__('Checkout|%{selectedPlanText} plan'),
    group: s__('Checkout|Group'),
    users: s__('Checkout|Users'),
  },
  stepId: STEPS[0].id,
};
</script>
<template>
  <step
    :step-id="$options.stepId"
    :title="$options.i18n.stepTitle"
    :is-valid="isValid"
    :next-step-button-text="$options.i18n.nextStepButtonText"
  >
    <template #body>
      <gl-form-group :label="$options.i18n.selectedPlanLabel" label-size="sm" class="mb-3">
        <gl-form-select
          v-model="selectedPlanModel"
          v-autofocusonshow
          :options="availablePlans"
          data-qa-selector="plan_name"
        />
      </gl-form-group>
      <gl-form-group
        v-if="isShowingGroupSelector"
        :label="$options.i18n.selectedGroupLabel"
        :description="groupSelectDescription"
        label-size="sm"
        class="mb-3"
      >
        <gl-form-select
          ref="group-select"
          v-model="selectedGroupModel"
          :options="groupOptionsWithDefault"
          data-qa-selector="group_name"
        />
      </gl-form-group>
      <gl-form-group
        v-if="isShowingNameOfCompanyInput"
        :label="$options.i18n.organizationNameLabel"
        label-size="sm"
        class="mb-3"
      >
        <gl-form-input ref="organization-name" v-model="organizationNameModel" type="text" />
      </gl-form-group>
      <div class="combined d-flex">
        <gl-form-group :label="$options.i18n.numberOfUsersLabel" label-size="sm" class="number">
          <gl-form-input
            ref="number-of-users"
            v-model.number="numberOfUsersModel"
            type="number"
            :min="selectedGroupUsers"
            :disabled="!isSetupForCompany"
            data-qa-selector="number_of_users"
          />
        </gl-form-group>
        <gl-form-group
          v-if="!isSetupForCompany"
          ref="company-link"
          class="label ml-3 align-self-end"
        >
          <gl-sprintf :message="$options.i18n.needMoreUsersLink">
            <template #company>
              <gl-link @click="toggleIsSetupForCompany">{{ $options.i18n.companyOrTeam }}</gl-link>
            </template>
          </gl-sprintf>
        </gl-form-group>
      </div>
    </template>
    <template #summary>
      <strong ref="summary-line-1">
        {{ selectedPlanTextLine }}
      </strong>
      <div v-if="isSetupForCompany" ref="summary-line-2">
        {{ $options.i18n.group }}: {{ organizationName || selectedGroupName }}
      </div>
      <div ref="summary-line-3">{{ $options.i18n.users }}: {{ numberOfUsers }}</div>
    </template>
  </step>
</template>
