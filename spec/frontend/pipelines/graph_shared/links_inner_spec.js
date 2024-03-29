import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { setHTMLFixture } from 'helpers/fixtures';
import axios from '~/lib/utils/axios_utils';
import {
  PIPELINES_DETAIL_LINK_DURATION,
  PIPELINES_DETAIL_LINKS_TOTAL,
  PIPELINES_DETAIL_LINKS_JOB_RATIO,
} from '~/performance/constants';
import * as perfUtils from '~/performance/utils';
import * as Api from '~/pipelines/components/graph_shared/api';
import LinksInner from '~/pipelines/components/graph_shared/links_inner.vue';
import * as sentryUtils from '~/pipelines/utils';
import { createJobsHash } from '~/pipelines/utils';
import {
  jobRect,
  largePipelineData,
  parallelNeedData,
  pipelineData,
  pipelineDataWithNoNeeds,
  rootRect,
} from '../pipeline_graph/mock_data';

describe('Links Inner component', () => {
  const containerId = 'pipeline-graph-container';
  const defaultProps = {
    containerId,
    containerMeasurements: { width: 1019, height: 445 },
    pipelineId: 1,
    pipelineData: [],
    totalGroups: 10,
  };

  let wrapper;

  const createComponent = (props) => {
    wrapper = shallowMount(LinksInner, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findLinkSvg = () => wrapper.find('#link-svg');
  const findAllLinksPath = () => findLinkSvg().findAll('path');

  // We create fixture so that each job has an empty div that represent
  // the JobPill in the DOM. Each `JobPill` would have different coordinates,
  // so we increment their coordinates on each iteration to simulat different positions.
  const setFixtures = ({ stages }) => {
    const jobs = createJobsHash(stages);
    const arrayOfJobs = Object.keys(jobs);

    const linksHtmlElements = arrayOfJobs.map((job) => {
      return `<div id=${job}-${defaultProps.pipelineId} />`;
    });

    setHTMLFixture(`<div id="${containerId}">${linksHtmlElements.join(' ')}</div>`);

    // We are mocking the clientRect data of each job and the container ID.
    jest
      .spyOn(document.getElementById(containerId), 'getBoundingClientRect')
      .mockImplementation(() => rootRect);

    arrayOfJobs.forEach((job, index) => {
      jest
        .spyOn(
          document.getElementById(`${job}-${defaultProps.pipelineId}`),
          'getBoundingClientRect',
        )
        .mockImplementation(() => {
          const newValue = 10 * index;
          const { left, right, top, bottom, x, y } = jobRect;
          return {
            ...jobRect,
            left: left + newValue,
            right: right + newValue,
            top: top + newValue,
            bottom: bottom + newValue,
            x: x + newValue,
            y: y + newValue,
          };
        });
    });
  };

  afterEach(() => {
    jest.restoreAllMocks();
    wrapper.destroy();
    wrapper = null;
  });

  describe('basic SVG creation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders an SVG of the right size', () => {
      expect(findLinkSvg().exists()).toBe(true);
      expect(findLinkSvg().attributes('width')).toBe(
        `${defaultProps.containerMeasurements.width}px`,
      );
      expect(findLinkSvg().attributes('height')).toBe(
        `${defaultProps.containerMeasurements.height}px`,
      );
    });
  });

  describe('no pipeline data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component', () => {
      expect(findLinkSvg().exists()).toBe(true);
      expect(findAllLinksPath()).toHaveLength(0);
    });
  });

  describe('pipeline data with no needs', () => {
    beforeEach(() => {
      createComponent({ pipelineData: pipelineDataWithNoNeeds.stages });
    });

    it('renders no links', () => {
      expect(findLinkSvg().exists()).toBe(true);
      expect(findAllLinksPath()).toHaveLength(0);
    });
  });

  describe('with one need', () => {
    beforeEach(() => {
      setFixtures(pipelineData);
      createComponent({ pipelineData: pipelineData.stages });
    });

    it('renders one link', () => {
      expect(findAllLinksPath()).toHaveLength(1);
    });

    it('path does not contain NaN values', () => {
      expect(wrapper.html()).not.toContain('NaN');
    });

    it('matches snapshot and has expected path', () => {
      expect(wrapper.html()).toMatchSnapshot();
    });
  });

  describe('with a parallel need', () => {
    beforeEach(() => {
      setFixtures(parallelNeedData);
      createComponent({ pipelineData: parallelNeedData.stages });
    });

    it('renders only one link for all the same parallel jobs', () => {
      expect(findAllLinksPath()).toHaveLength(1);
    });

    it('path does not contain NaN values', () => {
      expect(wrapper.html()).not.toContain('NaN');
    });

    it('matches snapshot and has expected path', () => {
      expect(wrapper.html()).toMatchSnapshot();
    });
  });

  describe('with a large number of needs', () => {
    beforeEach(() => {
      setFixtures(largePipelineData);
      createComponent({ pipelineData: largePipelineData.stages });
    });

    it('renders the correct number of links', () => {
      expect(findAllLinksPath()).toHaveLength(5);
    });

    it('path does not contain NaN values', () => {
      expect(wrapper.html()).not.toContain('NaN');
    });

    it('matches snapshot and has expected path', () => {
      expect(wrapper.html()).toMatchSnapshot();
    });
  });

  describe('interactions', () => {
    beforeEach(() => {
      setFixtures(largePipelineData);
      createComponent({ pipelineData: largePipelineData.stages });
    });

    it('highlight needs on hover', async () => {
      const firstLink = findAllLinksPath().at(0);

      const defaultColorClass = 'gl-stroke-gray-200';
      const hoverColorClass = 'gl-stroke-blue-400';

      expect(firstLink.classes(defaultColorClass)).toBe(true);
      expect(firstLink.classes(hoverColorClass)).toBe(false);

      // Because there is a watcher, we need to set the props after the component
      // has mounted.
      await wrapper.setProps({ highlightedJob: 'test_1' });

      expect(firstLink.classes(defaultColorClass)).toBe(false);
      expect(firstLink.classes(hoverColorClass)).toBe(true);
    });
  });

  describe('performance metrics', () => {
    let markAndMeasure;
    let reportToSentry;
    let reportPerformance;
    let mock;

    beforeEach(() => {
      mock = new MockAdapter(axios);
      jest.spyOn(window, 'requestAnimationFrame').mockImplementation((cb) => cb());
      markAndMeasure = jest.spyOn(perfUtils, 'performanceMarkAndMeasure');
      reportToSentry = jest.spyOn(sentryUtils, 'reportToSentry');
      reportPerformance = jest.spyOn(Api, 'reportPerformance');
    });

    afterEach(() => {
      mock.restore();
    });

    describe('with no metrics config object', () => {
      beforeEach(() => {
        setFixtures(pipelineData);
        createComponent({
          pipelineData: pipelineData.stages,
        });
      });

      it('is not called', () => {
        expect(markAndMeasure).not.toHaveBeenCalled();
        expect(reportToSentry).not.toHaveBeenCalled();
        expect(reportPerformance).not.toHaveBeenCalled();
      });
    });

    describe('with metrics config set to false', () => {
      beforeEach(() => {
        setFixtures(pipelineData);
        createComponent({
          pipelineData: pipelineData.stages,
          metricsConfig: {
            collectMetrics: false,
            metricsPath: '/path/to/metrics',
          },
        });
      });

      it('is not called', () => {
        expect(markAndMeasure).not.toHaveBeenCalled();
        expect(reportToSentry).not.toHaveBeenCalled();
        expect(reportPerformance).not.toHaveBeenCalled();
      });
    });

    describe('with no metrics path', () => {
      beforeEach(() => {
        setFixtures(pipelineData);
        createComponent({
          pipelineData: pipelineData.stages,
          metricsConfig: {
            collectMetrics: true,
            metricsPath: '',
          },
        });
      });

      it('is not called', () => {
        expect(markAndMeasure).not.toHaveBeenCalled();
        expect(reportToSentry).not.toHaveBeenCalled();
        expect(reportPerformance).not.toHaveBeenCalled();
      });
    });

    describe('with metrics path and collect set to true', () => {
      const metricsPath = '/root/project/-/ci/prometheus_metrics/histograms.json';
      const duration = 0.0478;
      const numLinks = 1;
      const metricsData = {
        histograms: [
          { name: PIPELINES_DETAIL_LINK_DURATION, value: duration / 1000 },
          { name: PIPELINES_DETAIL_LINKS_TOTAL, value: numLinks },
          {
            name: PIPELINES_DETAIL_LINKS_JOB_RATIO,
            value: numLinks / defaultProps.totalGroups,
          },
        ],
      };

      describe('when no duration is obtained', () => {
        beforeEach(() => {
          jest.spyOn(window.performance, 'getEntriesByName').mockImplementation(() => {
            return [];
          });

          setFixtures(pipelineData);

          createComponent({
            pipelineData: pipelineData.stages,
            metricsConfig: {
              collectMetrics: true,
              path: metricsPath,
            },
          });
        });

        it('attempts to collect metrics', () => {
          expect(markAndMeasure).toHaveBeenCalled();
          expect(reportPerformance).not.toHaveBeenCalled();
          expect(reportToSentry).not.toHaveBeenCalled();
        });
      });

      describe('with duration and no error', () => {
        beforeEach(() => {
          jest.spyOn(window.performance, 'getEntriesByName').mockImplementation(() => {
            return [{ duration }];
          });

          setFixtures(pipelineData);

          createComponent({
            pipelineData: pipelineData.stages,
            metricsConfig: {
              collectMetrics: true,
              path: metricsPath,
            },
          });
        });

        it('it calls reportPerformance with expected arguments', () => {
          expect(markAndMeasure).toHaveBeenCalled();
          expect(reportPerformance).toHaveBeenCalled();
          expect(reportPerformance).toHaveBeenCalledWith(metricsPath, metricsData);
          expect(reportToSentry).not.toHaveBeenCalled();
        });
      });
    });
  });
});
