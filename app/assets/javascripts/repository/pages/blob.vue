<script>
// This file is in progress and behind a feature flag, please see the following issue for more:
// https://gitlab.com/gitlab-org/gitlab/-/issues/323200

import BlobContentViewer from '../components/blob_content_viewer.vue';

export default {
  components: {
    BlobContentViewer,
  },
  props: {
    path: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <blob-content-viewer :path="path" />
</template>
