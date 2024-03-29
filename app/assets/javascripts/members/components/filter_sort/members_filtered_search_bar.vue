<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { mapState } from 'vuex';
import { getParameterByName } from '~/lib/utils/common_utils';
import { setUrlParams, queryToObject } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import { SEARCH_TOKEN_TYPE, SORT_PARAM } from '~/members/constants';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

export default {
  name: 'MembersFilteredSearchBar',
  components: { FilteredSearchBar },
  availableTokens: [
    {
      type: 'two_factor',
      icon: 'lock',
      title: s__('Members|2FA'),
      token: GlFilteredSearchToken,
      unique: true,
      operators: [{ value: '=', description: 'is' }],
      options: [
        { value: 'enabled', title: s__('Members|Enabled') },
        { value: 'disabled', title: s__('Members|Disabled') },
      ],
      requiredPermissions: 'canManageMembers',
    },
    {
      type: 'with_inherited_permissions',
      icon: 'group',
      title: s__('Members|Membership'),
      token: GlFilteredSearchToken,
      unique: true,
      operators: [{ value: '=', description: 'is' }],
      options: [
        { value: 'exclude', title: s__('Members|Direct') },
        { value: 'only', title: s__('Members|Inherited') },
      ],
    },
  ],
  inject: ['namespace', 'sourceId', 'canManageMembers'],
  data() {
    return {
      initialFilterValue: [],
    };
  },
  computed: {
    ...mapState({
      filteredSearchBar(state) {
        return state[this.namespace].filteredSearchBar;
      },
    }),
    tokens() {
      return this.$options.availableTokens.filter((token) => {
        if (
          Object.prototype.hasOwnProperty.call(token, 'requiredPermissions') &&
          !this[token.requiredPermissions]
        ) {
          return false;
        }

        return this.filteredSearchBar.tokens?.includes(token.type);
      });
    },
  },
  created() {
    const query = queryToObject(window.location.search);

    const tokens = this.tokens
      .filter((token) => query[token.type])
      .map((token) => ({
        type: token.type,
        value: {
          data: query[token.type],
          operator: '=',
        },
      }));

    if (query[this.filteredSearchBar.searchParam]) {
      tokens.push({
        type: SEARCH_TOKEN_TYPE,
        value: {
          data: query[this.filteredSearchBar.searchParam],
        },
      });
    }

    this.initialFilterValue = tokens;
  },
  methods: {
    handleFilter(tokens) {
      const params = tokens.reduce((accumulator, token) => {
        const { type, value } = token;

        if (!type || !value) {
          return accumulator;
        }

        if (type === SEARCH_TOKEN_TYPE) {
          if (value.data !== '') {
            return {
              ...accumulator,
              [this.filteredSearchBar.searchParam]: value.data,
            };
          }
        } else {
          return {
            ...accumulator,
            [type]: value.data,
          };
        }

        return accumulator;
      }, {});

      const sortParam = getParameterByName(SORT_PARAM);

      window.location.href = setUrlParams(
        { ...params, ...(sortParam && { sort: sortParam }) },
        window.location.href,
        true,
      );
    },
  },
};
</script>

<template>
  <filtered-search-bar
    :namespace="sourceId.toString()"
    :tokens="tokens"
    :recent-searches-storage-key="filteredSearchBar.recentSearchesStorageKey"
    :search-input-placeholder="filteredSearchBar.placeholder"
    :initial-filter-value="initialFilterValue"
    data-testid="members-filtered-search-bar"
    @onFilter="handleFilter"
  />
</template>
