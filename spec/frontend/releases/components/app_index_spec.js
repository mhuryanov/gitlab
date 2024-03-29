import { shallowMount, createLocalVue } from '@vue/test-utils';
import { range as rge } from 'lodash';
import Vuex from 'vuex';
import { getJSONFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import api from '~/api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import ReleasesApp from '~/releases/components/app_index.vue';
import ReleasesPagination from '~/releases/components/releases_pagination.vue';
import createStore from '~/releases/stores';
import createIndexModule from '~/releases/stores/modules/index';
import { pageInfoHeadersWithoutPagination, pageInfoHeadersWithPagination } from '../mock_data';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  getParameterByName: jest.fn().mockImplementation((paramName) => {
    return `${paramName}_param_value`;
  }),
}));

const localVue = createLocalVue();
localVue.use(Vuex);

const release = getJSONFixture('api/releases/release.json');
const releases = [release];

describe('Releases App ', () => {
  let wrapper;
  let fetchReleaseSpy;

  const paginatedReleases = rge(21).map((index) => ({
    ...convertObjectPropsToCamelCase(release, { deep: true }),
    tagName: `${index}.00`,
  }));

  const defaultInitialState = {
    projectId: 'gitlab-ce',
    projectPath: 'gitlab-org/gitlab-ce',
    documentationPath: 'help/releases',
    illustrationPath: 'illustration/path',
  };

  const createComponent = (stateUpdates = {}) => {
    const indexModule = createIndexModule({
      ...defaultInitialState,
      ...stateUpdates,
    });

    fetchReleaseSpy = jest.spyOn(indexModule.actions, 'fetchReleases');

    const store = createStore({
      modules: { index: indexModule },
      featureFlags: {
        graphqlReleaseData: true,
        graphqlReleasesPage: false,
        graphqlMilestoneStats: true,
      },
    });

    wrapper = shallowMount(ReleasesApp, {
      store,
      localVue,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('on startup', () => {
    beforeEach(() => {
      jest
        .spyOn(api, 'releases')
        .mockResolvedValue({ data: releases, headers: pageInfoHeadersWithoutPagination });

      createComponent();
    });

    it('calls fetchRelease with the page, before, and after parameters', () => {
      expect(fetchReleaseSpy).toHaveBeenCalledTimes(1);
      expect(fetchReleaseSpy).toHaveBeenCalledWith(expect.anything(), {
        page: 'page_param_value',
        before: 'before_param_value',
        after: 'after_param_value',
      });
    });
  });

  describe('while loading', () => {
    beforeEach(() => {
      jest
        .spyOn(api, 'releases')
        // Need to defer the return value here to the next stack,
        // otherwise the loading state disappears before our test even starts.
        .mockImplementation(() => waitForPromises().then(() => ({ data: [], headers: {} })));

      createComponent();
    });

    it('renders loading icon', () => {
      expect(wrapper.find('.js-loading').exists()).toBe(true);
      expect(wrapper.find('.js-empty-state').exists()).toBe(false);
      expect(wrapper.find('.js-success-state').exists()).toBe(false);
      expect(wrapper.find(ReleasesPagination).exists()).toBe(false);
    });
  });

  describe('with successful request', () => {
    beforeEach(() => {
      jest
        .spyOn(api, 'releases')
        .mockResolvedValue({ data: releases, headers: pageInfoHeadersWithoutPagination });

      createComponent();
    });

    it('renders success state', () => {
      expect(wrapper.find('.js-loading').exists()).toBe(false);
      expect(wrapper.find('.js-empty-state').exists()).toBe(false);
      expect(wrapper.find('.js-success-state').exists()).toBe(true);
      expect(wrapper.find(ReleasesPagination).exists()).toBe(true);
    });
  });

  describe('with successful request and pagination', () => {
    beforeEach(() => {
      jest
        .spyOn(api, 'releases')
        .mockResolvedValue({ data: paginatedReleases, headers: pageInfoHeadersWithPagination });

      createComponent();
    });

    it('renders success state', () => {
      expect(wrapper.find('.js-loading').exists()).toBe(false);
      expect(wrapper.find('.js-empty-state').exists()).toBe(false);
      expect(wrapper.find('.js-success-state').exists()).toBe(true);
      expect(wrapper.find(ReleasesPagination).exists()).toBe(true);
    });
  });

  describe('with empty request', () => {
    beforeEach(() => {
      jest.spyOn(api, 'releases').mockResolvedValue({ data: [], headers: {} });

      createComponent();
    });

    it('renders empty state', () => {
      expect(wrapper.find('.js-loading').exists()).toBe(false);
      expect(wrapper.find('.js-empty-state').exists()).toBe(true);
      expect(wrapper.find('.js-success-state').exists()).toBe(false);
    });
  });

  describe('"New release" button', () => {
    const findNewReleaseButton = () => wrapper.find('.js-new-release-btn');

    beforeEach(() => {
      jest.spyOn(api, 'releases').mockResolvedValue({ data: [], headers: {} });
    });

    describe('when the user is allowed to create a new Release', () => {
      const newReleasePath = 'path/to/new/release';

      beforeEach(() => {
        createComponent({ newReleasePath });
      });

      it('renders the "New release" button', () => {
        expect(findNewReleaseButton().exists()).toBe(true);
      });

      it('renders the "New release" button with the correct href', () => {
        expect(findNewReleaseButton().attributes('href')).toBe(newReleasePath);
      });
    });

    describe('when the user is not allowed to create a new Release', () => {
      beforeEach(() => createComponent());

      it('does not render the "New release" button', () => {
        expect(findNewReleaseButton().exists()).toBe(false);
      });
    });
  });

  describe('when the back button is pressed', () => {
    beforeEach(() => {
      jest
        .spyOn(api, 'releases')
        .mockResolvedValue({ data: releases, headers: pageInfoHeadersWithoutPagination });

      createComponent();

      fetchReleaseSpy.mockClear();

      window.dispatchEvent(new PopStateEvent('popstate'));
    });

    it('calls fetchRelease with the page parameter', () => {
      expect(fetchReleaseSpy).toHaveBeenCalledTimes(1);
      expect(fetchReleaseSpy).toHaveBeenCalledWith(expect.anything(), {
        page: 'page_param_value',
        before: 'before_param_value',
        after: 'after_param_value',
      });
    });
  });
});
