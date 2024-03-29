import { shallowMount } from '@vue/test-utils';

import PackagesListRow from '~/packages/shared/components/package_list_row.vue';
import PackagePath from '~/packages/shared/components/package_path.vue';
import PackageTags from '~/packages/shared/components/package_tags.vue';

import ListItem from '~/vue_shared/components/registry/list_item.vue';
import { packageList } from '../../mock_data';

describe('packages_list_row', () => {
  let wrapper;
  let store;

  const [packageWithoutTags, packageWithTags] = packageList;

  const InfrastructureIconAndName = { name: 'InfrastructureIconAndName', template: '<div></div>' };
  const PackageIconAndName = { name: 'PackageIconAndName', template: '<div></div>' };

  const findPackageTags = () => wrapper.find(PackageTags);
  const findPackagePath = () => wrapper.find(PackagePath);
  const findDeleteButton = () => wrapper.find('[data-testid="action-delete"]');
  const findPackageIconAndName = () => wrapper.find(PackageIconAndName);
  const findInfrastructureIconAndName = () => wrapper.find(InfrastructureIconAndName);

  const mountComponent = ({
    isGroup = false,
    packageEntity = packageWithoutTags,
    showPackageType = true,
    disableDelete = false,
    provide,
  } = {}) => {
    wrapper = shallowMount(PackagesListRow, {
      store,
      provide,
      stubs: {
        ListItem,
        InfrastructureIconAndName,
        PackageIconAndName,
      },
      propsData: {
        packageLink: 'foo',
        packageEntity,
        isGroup,
        showPackageType,
        disableDelete,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  it('renders', () => {
    mountComponent();
    expect(wrapper.element).toMatchSnapshot();
  });

  describe('tags', () => {
    it('renders package tags when a package has tags', () => {
      mountComponent({ isGroup: false, packageEntity: packageWithTags });

      expect(findPackageTags().exists()).toBe(true);
    });

    it('does not render when there are no tags', () => {
      mountComponent();

      expect(findPackageTags().exists()).toBe(false);
    });
  });

  describe('when is is group', () => {
    it('has a package path component', () => {
      mountComponent({ isGroup: true });

      expect(findPackagePath().exists()).toBe(true);
      expect(findPackagePath().props()).toMatchObject({ path: 'foo/bar/baz' });
    });
  });

  describe('showPackageType', () => {
    it('shows the type when set', () => {
      mountComponent();

      expect(findPackageIconAndName().exists()).toBe(true);
    });

    it('does not show the type when not set', () => {
      mountComponent({ showPackageType: false });

      expect(findPackageIconAndName().exists()).toBe(false);
    });
  });

  describe('deleteAvailable', () => {
    it('does not show when not set', () => {
      mountComponent({ disableDelete: true });

      expect(findDeleteButton().exists()).toBe(false);
    });
  });

  describe('delete button', () => {
    it('exists and has the correct props', () => {
      mountComponent({ packageEntity: packageWithoutTags });

      expect(findDeleteButton().exists()).toBe(true);
      expect(findDeleteButton().attributes()).toMatchObject({
        icon: 'remove',
        category: 'secondary',
        variant: 'danger',
        title: 'Remove package',
      });
    });

    it('emits the packageToDelete event when the delete button is clicked', async () => {
      mountComponent({ packageEntity: packageWithoutTags });

      findDeleteButton().vm.$emit('click');

      await wrapper.vm.$nextTick();
      expect(wrapper.emitted('packageToDelete')).toBeTruthy();
      expect(wrapper.emitted('packageToDelete')[0]).toEqual([packageWithoutTags]);
    });
  });

  describe('Infrastructure config', () => {
    it('defaults to package registry components', () => {
      mountComponent();

      expect(findPackageIconAndName().exists()).toBe(true);
      expect(findInfrastructureIconAndName().exists()).toBe(false);
    });

    it('mounts different component based on the provided values', () => {
      mountComponent({
        provide: {
          iconComponent: 'InfrastructureIconAndName',
        },
      });

      expect(findPackageIconAndName().exists()).toBe(false);

      expect(findInfrastructureIconAndName().exists()).toBe(true);
    });
  });
});
