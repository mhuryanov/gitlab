<script>
import { GlFormGroup, GlFormInput, GlFormSelect } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { mapState, mapActions } from 'vuex';
import Step from 'ee/vue_shared/purchase_flow/components/step.vue';
import { s__ } from '~/locale';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import { STEPS } from '../../constants';

export default {
  components: {
    Step,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
  },
  directives: {
    autofocusonshow,
  },
  computed: {
    ...mapState([
      'country',
      'streetAddressLine1',
      'streetAddressLine2',
      'city',
      'countryState',
      'zipCode',
      'countryOptions',
      'stateOptions',
    ]),
    countryModel: {
      get() {
        return this.country;
      },
      set(country) {
        this.updateCountry(country);
      },
    },
    streetAddressLine1Model: {
      get() {
        return this.streetAddressLine1;
      },
      set(streetAddressLine1) {
        this.updateStreetAddressLine1(streetAddressLine1);
      },
    },
    streetAddressLine2Model: {
      get() {
        return this.streetAddressLine2;
      },
      set(streetAddressLine2) {
        this.updateStreetAddressLine2(streetAddressLine2);
      },
    },
    cityModel: {
      get() {
        return this.city;
      },
      set(city) {
        this.updateCity(city);
      },
    },
    countryStateModel: {
      get() {
        return this.countryState;
      },
      set(countryState) {
        this.updateCountryState(countryState);
      },
    },
    zipCodeModel: {
      get() {
        return this.zipCode;
      },
      set(zipCode) {
        this.updateZipCode(zipCode);
      },
    },
    isValid() {
      return (
        !isEmpty(this.country) &&
        !isEmpty(this.streetAddressLine1) &&
        !isEmpty(this.city) &&
        !isEmpty(this.zipCode)
      );
    },
    countryOptionsWithDefault() {
      return [
        {
          text: this.$options.i18n.countrySelectPrompt,
          value: null,
        },
        ...this.countryOptions,
      ];
    },
    stateOptionsWithDefault() {
      return [
        {
          text: this.$options.i18n.stateSelectPrompt,
          value: null,
        },
        ...this.stateOptions,
      ];
    },
  },
  mounted() {
    this.fetchCountries();
  },
  methods: {
    ...mapActions([
      'fetchCountries',
      'fetchStates',
      'updateCountry',
      'updateStreetAddressLine1',
      'updateStreetAddressLine2',
      'updateCity',
      'updateCountryState',
      'updateZipCode',
    ]),
  },
  i18n: {
    stepTitle: s__('Checkout|Billing address'),
    nextStepButtonText: s__('Checkout|Continue to payment'),
    countryLabel: s__('Checkout|Country'),
    countrySelectPrompt: s__('Checkout|Please select a country'),
    streetAddressLabel: s__('Checkout|Street address'),
    cityLabel: s__('Checkout|City'),
    stateLabel: s__('Checkout|State'),
    stateSelectPrompt: s__('Checkout|Please select a state'),
    zipCodeLabel: s__('Checkout|Zip code'),
  },
  stepId: STEPS[1].id,
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
      <gl-form-group :label="$options.i18n.countryLabel" label-size="sm" class="mb-3">
        <gl-form-select
          v-model="countryModel"
          v-autofocusonshow
          :options="countryOptionsWithDefault"
          class="js-country"
          data-qa-selector="country"
          @change="fetchStates"
        />
      </gl-form-group>
      <gl-form-group :label="$options.i18n.streetAddressLabel" label-size="sm" class="mb-3">
        <gl-form-input
          v-model="streetAddressLine1Model"
          type="text"
          data-qa-selector="street_address_1"
        />
        <gl-form-input
          v-model="streetAddressLine2Model"
          type="text"
          data-qa-selector="street_address_2"
        />
      </gl-form-group>
      <gl-form-group :label="$options.i18n.cityLabel" label-size="sm" class="mb-3">
        <gl-form-input v-model="cityModel" type="text" data-qa-selector="city" />
      </gl-form-group>
      <div class="combined d-flex">
        <gl-form-group :label="$options.i18n.stateLabel" label-size="sm" class="mr-3 w-50">
          <gl-form-select
            v-model="countryStateModel"
            :options="stateOptionsWithDefault"
            data-qa-selector="state"
          />
        </gl-form-group>
        <gl-form-group :label="$options.i18n.zipCodeLabel" label-size="sm" class="w-50">
          <gl-form-input v-model="zipCodeModel" type="text" data-qa-selector="zip_code" />
        </gl-form-group>
      </div>
    </template>
    <template #summary>
      <div class="js-summary-line-1">{{ streetAddressLine1 }}</div>
      <div class="js-summary-line-2">{{ streetAddressLine2 }}</div>
      <div class="js-summary-line-3">{{ city }}, {{ countryState }} {{ zipCode }}</div>
    </template>
  </step>
</template>
