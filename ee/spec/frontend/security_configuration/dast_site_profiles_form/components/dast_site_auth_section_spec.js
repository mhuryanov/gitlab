import { GlFormCheckbox } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import DastSiteAuthSection from 'ee/security_configuration/dast_site_profiles_form/components/dast_site_auth_section.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

describe('DastSiteAuthSection', () => {
  let wrapper;

  const createComponent = ({ mountFn = mount, fields = {}, disabled = false } = {}) => {
    wrapper = extendedWrapper(
      mountFn(DastSiteAuthSection, {
        propsData: {
          disabled,
          value: { fields },
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  const findParentFormGroup = () => wrapper.findByTestId('dast-site-auth-parent-group');
  const findByNameAttribute = (name) => wrapper.find(`[name="${name}"]`);
  const findAuthForm = () => wrapper.findByTestId('auth-form');
  const findAuthCheckbox = () => wrapper.find(GlFormCheckbox);

  const setAuthentication = ({ enabled }) => {
    findAuthCheckbox().vm.$emit('input', enabled);
    return wrapper.vm.$nextTick();
  };
  const getLatestInputEventPayload = () => {
    const latestInputEvent = [...wrapper.emitted('input')].pop();
    const [payload] = latestInputEvent;
    return payload;
  };

  describe('authentication toggle', () => {
    it('is set false by default', () => {
      createComponent();
      expect(findAuthCheckbox().vm.$attrs.checked).toBe(false);
    });

    it.each([true, false])(
      'is set correctly when the "enabled" field is set to "%s"',
      (authEnabled) => {
        createComponent({ fields: { enabled: authEnabled } });
        expect(findAuthCheckbox().vm.$attrs.checked).toBe(authEnabled);
      },
    );

    it('controls the visibility of the authentication-fields form', async () => {
      expect(findAuthForm().exists()).toBe(false);
      await setAuthentication({ enabled: true });
      expect(findAuthForm().exists()).toBe(true);
    });

    it.each([true, false])(
      'makes the component emit an "input" event when changed',
      async (enabled) => {
        await setAuthentication({ enabled });
        expect(getLatestInputEventPayload().fields.enabled.value).toBe(enabled);
      },
    );
  });

  describe('authentication form', () => {
    beforeEach(async () => {
      await setAuthentication({ enabled: true });
    });

    const inputFieldsWithValues = {
      url: 'http://www.gitlab.com',
      username: 'foo',
      password: 'foo',
      usernameField: 'foo',
      passwordField: 'foo',
    };

    const inputFieldNames = Object.keys(inputFieldsWithValues);

    describe.each(inputFieldNames)('input field "%s"', (inputFieldName) => {
      it('is rendered', () => {
        expect(findByNameAttribute(inputFieldName).exists()).toBe(true);
      });

      it('makes the component emit an "input" event when its value changes', () => {
        const input = findByNameAttribute(inputFieldName);
        const newValue = 'foo';

        input.setValue(newValue);

        expect(getLatestInputEventPayload().fields[inputFieldName].value).toBe(newValue);
      });
    });

    describe('validity', () => {
      it('is not valid per default', () => {
        expect(getLatestInputEventPayload().state).toBe(false);
      });

      it('is valid when correct values are passed in via the "fields" prop', async () => {
        createComponent({ fields: inputFieldsWithValues });

        await setAuthentication({ enabled: true });

        expect(getLatestInputEventPayload().state).toBe(true);
      });

      it('is valid once all fields have been entered correctly', () => {
        Object.entries(inputFieldsWithValues).forEach(([inputFieldName, inputFieldValue]) => {
          const input = findByNameAttribute(inputFieldName);
          input.setValue(inputFieldValue);
          input.trigger('blur');
        });

        expect(getLatestInputEventPayload().state).toBe(true);
      });
    });

    describe('when profile does not come from a policy', () => {
      it('should enable all form groups', () => {
        createComponent({ mountFn: shallowMount, fields: { enabled: true } });
        expect(findParentFormGroup().attributes('disabled')).toBe(undefined);
      });
    });

    describe('when profile does comes from a policy', () => {
      it('should disable all form groups', () => {
        createComponent({ mountFn: shallowMount, disabled: true, fields: { enabled: true } });
        expect(findParentFormGroup().attributes('disabled')).toBe('true');
      });
    });
  });
});
