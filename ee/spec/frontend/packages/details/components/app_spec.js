import Vuex from 'vuex';
import { mount, createLocalVue } from '@vue/test-utils';
import { GlEmptyState, GlModal } from '@gitlab/ui';
import Tracking from '~/tracking';
import * as getters from 'ee/packages/details/store/getters';
import PackagesApp from 'ee/packages/details/components/app.vue';
import PackageTitle from 'ee/packages/details/components/package_title.vue';
import PackageInformation from 'ee/packages/details/components/information.vue';
import NpmInstallation from 'ee/packages/details/components/npm_installation.vue';
import MavenInstallation from 'ee/packages/details/components/maven_installation.vue';
import * as SharedUtils from 'ee/packages/shared/utils';
import { TrackingActions } from 'ee/packages/shared/constants';
import PackagesListLoader from 'ee/packages/shared/components/packages_list_loader.vue';
import PackageListRow from 'ee/packages/shared/components/package_list_row.vue';
import ConanInstallation from 'ee/packages/details/components/conan_installation.vue';
import NugetInstallation from 'ee/packages/details/components/nuget_installation.vue';
import PypiInstallation from 'ee/packages/details/components/pypi_installation.vue';
import {
  conanPackage,
  mavenPackage,
  mavenFiles,
  npmPackage,
  npmFiles,
  nugetPackage,
  pypiPackage,
} from '../../mock_data';
import stubChildren from 'helpers/stub_children';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('PackagesApp', () => {
  let wrapper;
  let store;
  const fetchPackageVersions = jest.fn();

  function createComponent({
    packageEntity = mavenPackage,
    packageFiles = mavenFiles,
    isLoading = false,
  } = {}) {
    store = new Vuex.Store({
      state: {
        isLoading,
        packageEntity,
        packageFiles,
        canDelete: true,
        destroyPath: 'destroy-package-path',
        emptySvgPath: 'empty-illustration',
        npmPath: 'foo',
        npmHelpPath: 'foo',
      },
      actions: {
        fetchPackageVersions,
      },
      getters,
    });

    wrapper = mount(PackagesApp, {
      localVue,
      store,
      stubs: {
        ...stubChildren(PackagesApp),
        GlDeprecatedButton: false,
        GlLink: false,
        GlModal: false,
        GlTab: false,
        GlTabs: false,
        GlTable: false,
      },
    });
  }

  const packageTitle = () => wrapper.find(PackageTitle);
  const emptyState = () => wrapper.find(GlEmptyState);
  const allPackageInformation = () => wrapper.findAll(PackageInformation);
  const packageInformation = index => allPackageInformation().at(index);
  const npmInstallation = () => wrapper.find(NpmInstallation);
  const mavenInstallation = () => wrapper.find(MavenInstallation);
  const conanInstallation = () => wrapper.find(ConanInstallation);
  const nugetInstallation = () => wrapper.find(NugetInstallation);
  const pypiInstallation = () => wrapper.find(PypiInstallation);
  const allFileRows = () => wrapper.findAll('.js-file-row');
  const firstFileDownloadLink = () => wrapper.find('.js-file-download');
  const deleteButton = () => wrapper.find('.js-delete-button');
  const deleteModal = () => wrapper.find(GlModal);
  const modalDeleteButton = () => wrapper.find({ ref: 'modal-delete-button' });
  const versionsTab = () => wrapper.find('.js-versions-tab > a');
  const packagesLoader = () => wrapper.find(PackagesListLoader);
  const packagesVersionRows = () => wrapper.findAll(PackageListRow);
  const noVersionsMessage = () => wrapper.find('[data-testid="no-versions-message"]');

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders the app and displays the package title', () => {
    createComponent();

    expect(packageTitle()).toExist();
  });

  it('renders an empty state component when no an invalid package is passed as a prop', () => {
    createComponent({
      packageEntity: {},
    });

    expect(emptyState()).toExist();
  });

  it('renders package information and metadata for packages containing both information and metadata', () => {
    createComponent();

    expect(packageInformation(0)).toExist();
    expect(packageInformation(1)).toExist();
  });

  it('does not render package metadata for npm as npm packages do not contain metadata', () => {
    createComponent({ packageEntity: npmPackage, packageFiles: npmFiles });

    expect(packageInformation(0)).toExist();
    expect(allPackageInformation()).toHaveLength(1);
  });

  describe('installation instructions', () => {
    describe.each`
      packageEntity   | selector
      ${conanPackage} | ${conanInstallation}
      ${mavenPackage} | ${mavenInstallation}
      ${npmPackage}   | ${npmInstallation}
      ${nugetPackage} | ${nugetInstallation}
      ${pypiPackage}  | ${pypiInstallation}
    `('renders', ({ packageEntity, selector }) => {
      it(`${packageEntity.package_type} instructions`, () => {
        createComponent({ packageEntity });

        expect(selector()).toExist();
      });
    });
  });

  it('renders a single file for an npm package as they only contain one file', () => {
    createComponent({ packageEntity: npmPackage, packageFiles: npmFiles });

    expect(allFileRows()).toExist();
    expect(allFileRows()).toHaveLength(1);
  });

  it('renders multiple files for a package that contains more than one file', () => {
    createComponent();

    expect(allFileRows()).toExist();
    expect(allFileRows()).toHaveLength(2);
  });

  it('allows the user to download a package file by rendering a download link', () => {
    createComponent();

    expect(allFileRows()).toExist();
    expect(firstFileDownloadLink().vm.$attrs.href).toContain('download');
  });

  describe('deleting packages', () => {
    beforeEach(() => {
      createComponent();
      deleteButton().trigger('click');
    });

    it('shows the delete confirmation modal when delete is clicked', () => {
      expect(deleteModal()).toExist();
    });
  });

  describe('versions', () => {
    describe('api call', () => {
      beforeEach(() => {
        createComponent();
      });

      it('makes api request on first click of tab', () => {
        versionsTab().trigger('click');

        expect(fetchPackageVersions).toHaveBeenCalled();
      });
    });

    it('displays the loader when state is loading', () => {
      createComponent({ isLoading: true });

      expect(packagesLoader().exists()).toBe(true);
    });

    it('displays the correct version count when the package has versions', () => {
      createComponent({ packageEntity: npmPackage });

      expect(packagesVersionRows()).toHaveLength(npmPackage.versions.length);
    });

    it('displays the no versions message when there are none', () => {
      createComponent();

      expect(noVersionsMessage().exists()).toBe(true);
    });
  });

  describe('tracking', () => {
    let eventSpy;
    let utilSpy;
    const category = 'foo';

    beforeEach(() => {
      eventSpy = jest.spyOn(Tracking, 'event');
      utilSpy = jest.spyOn(SharedUtils, 'packageTypeToTrackCategory').mockReturnValue(category);
    });

    it('tracking category calls packageTypeToTrackCategory', () => {
      createComponent({ packageEntity: conanPackage });
      expect(wrapper.vm.tracking.category).toBe(category);
      expect(utilSpy).toHaveBeenCalledWith('conan');
    });

    it(`delete button on delete modal call event with ${TrackingActions.DELETE_PACKAGE}`, () => {
      createComponent({ packageEntity: conanPackage });
      deleteButton().trigger('click');
      return wrapper.vm.$nextTick().then(() => {
        modalDeleteButton().trigger('click');
        expect(eventSpy).toHaveBeenCalledWith(
          category,
          TrackingActions.DELETE_PACKAGE,
          expect.any(Object),
        );
      });
    });

    it(`file download link call event with ${TrackingActions.PULL_PACKAGE}`, () => {
      createComponent({ packageEntity: conanPackage });
      firstFileDownloadLink().trigger('click');
      expect(eventSpy).toHaveBeenCalledWith(
        category,
        TrackingActions.PULL_PACKAGE,
        expect.any(Object),
      );
    });
  });
});
