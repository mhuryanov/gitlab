import { InMemoryCache } from 'apollo-cache-inmemory';
import { createMockClient } from 'mock-apollo-client';
import VueApollo from 'vue-apollo';

const defaultCacheOptions = {
  fragmentMatcher: { match: () => true },
  addTypename: false,
};

export default (handlers = [], resolvers = {}, cacheOptions = {}) => {
  const cache = new InMemoryCache({
    ...defaultCacheOptions,
    ...cacheOptions,
  });

  const mockClient = createMockClient({ cache, resolvers });

  if (Array.isArray(handlers)) {
    handlers.forEach(([query, value]) => mockClient.setRequestHandler(query, value));
  } else {
    throw new Error('You should pass an array of handlers to mock Apollo client');
  }

  const apolloProvider = new VueApollo({ defaultClient: mockClient });

  return apolloProvider;
};
