import ActionCable from '@rails/actioncable';
import { shallowMount } from '@vue/test-utils';
import AssigneesRealtime from '~/sidebar/components/assignees/assignees_realtime.vue';
import { assigneesQueries } from '~/sidebar/constants';
import SidebarMediator from '~/sidebar/sidebar_mediator';
import Mock from './mock_data';

jest.mock('@rails/actioncable', () => {
  const mockConsumer = {
    subscriptions: { create: jest.fn().mockReturnValue({ unsubscribe: jest.fn() }) },
  };
  return {
    createConsumer: jest.fn().mockReturnValue(mockConsumer),
  };
});

describe('Assignees Realtime', () => {
  let wrapper;
  let mediator;

  const createComponent = (issuableType = 'issue') => {
    wrapper = shallowMount(AssigneesRealtime, {
      propsData: {
        issuableIid: '1',
        mediator,
        projectPath: 'path/to/project',
        issuableType,
      },
      mocks: {
        $apollo: {
          query: assigneesQueries[issuableType].query,
          queries: {
            workspace: {
              refetch: jest.fn(),
            },
          },
        },
      },
    });
  };

  beforeEach(() => {
    mediator = new SidebarMediator(Mock.mediator);
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
    SidebarMediator.singleton = null;
  });

  describe('when handleFetchResult is called from smart query', () => {
    it('sets assignees to the store', () => {
      const data = {
        workspace: {
          issuable: {
            assignees: {
              nodes: [{ id: 'gid://gitlab/Environments/123', avatarUrl: 'url' }],
            },
          },
        },
      };
      const expected = [{ id: 123, avatar_url: 'url', avatarUrl: 'url' }];
      createComponent();

      wrapper.vm.handleFetchResult({ data });

      expect(mediator.store.assignees).toEqual(expected);
    });
  });

  describe('when mounted', () => {
    it('calls create subscription', () => {
      const cable = ActionCable.createConsumer();

      createComponent();

      return wrapper.vm.$nextTick().then(() => {
        expect(cable.subscriptions.create).toHaveBeenCalledTimes(1);
        expect(cable.subscriptions.create).toHaveBeenCalledWith(
          {
            channel: 'IssuesChannel',
            iid: wrapper.props('issuableIid'),
            project_path: wrapper.props('projectPath'),
          },
          { received: wrapper.vm.received },
        );
      });
    });
  });

  describe('when subscription is recieved', () => {
    it('refetches the GraphQL project query', () => {
      createComponent();

      wrapper.vm.received({ event: 'updated' });

      return wrapper.vm.$nextTick().then(() => {
        expect(wrapper.vm.$apollo.queries.workspace.refetch).toHaveBeenCalledTimes(1);
      });
    });
  });
});
