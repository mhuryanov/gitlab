import axios from '~/lib/utils/axios_utils';
import { reportToSentry } from '../../utils';

export const reportPerformance = (path, stats) => {
  axios.post(path, stats).catch((err) => {
    reportToSentry('links_inner_perf', `error: ${err}`);
  });
};
