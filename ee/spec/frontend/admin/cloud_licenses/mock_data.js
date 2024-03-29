import { subscriptionType } from 'ee/pages/admin/cloud_licenses/constants';

export const license = {
  ULTIMATE: {
    activatedAt: '2022-03-16',
    billableUsersCount: '8',
    expiresAt: '2022-03-16',
    company: 'ACME Corp',
    email: 'user@acmecorp.com',
    id: 'gid://gitlab/License/13',
    lastSync: '2021-03-16T00:00:00.000',
    maximumUserCount: '8',
    name: 'Jane Doe',
    plan: 'ultimate',
    startsAt: '2021-03-11',
    type: subscriptionType.CLOUD,
    usersInLicenseCount: '10',
    usersOverLicenseCount: '0',
  },
};

export const subscriptionHistory = [
  {
    activatedAt: '2022-03-16',
    company: 'ACME Corp',
    email: 'user@acmecorp.com',
    expiresAt: '2022-03-16',
    id: 'gid://gitlab/License/13',
    name: 'Jane Doe',
    plan: 'ultimate',
    startsAt: '2021-03-11',
    type: subscriptionType.CLOUD,
    usersInLicenseCount: '10',
  },
  {
    activatedAt: '2020-11-05',
    company: 'ACME Corp',
    email: 'user@acmecorp.com',
    expiresAt: '2021-03-16',
    id: 'gid://gitlab/License/11',
    name: 'Jane Doe',
    plan: 'premium',
    startsAt: '2020-03-16',
    type: subscriptionType.LEGACY,
    usersInLicenseCount: '5',
  },
];

export const activateLicenseMutationResponse = {
  FAILURE: [
    {
      errors: [
        {
          message:
            'Variable $gitlabSubscriptionActivateInput of type GitlabSubscriptionActivateInput! was provided invalid value',
          locations: [
            {
              line: 1,
              column: 11,
            },
          ],
          extensions: {
            value: null,
            problems: [
              {
                path: [],
                explanation: 'Expected value to not be null',
              },
            ],
          },
        },
      ],
    },
  ],
  FAILURE_IN_DISGUISE: {
    data: {
      gitlabSubscriptionActivate: {
        license: null,
        errors: ["undefined method `[]' for nil:NilClass"],
        __typename: 'GitlabSubscriptionActivatePayload',
      },
    },
  },
  SUCCESS: {
    data: {
      gitlabSubscriptionActivate: {
        license: {
          id: 'gid://gitlab/License/3',
          type: 'legacy',
          plan: 'ultimate',
          name: 'Test license',
          email: 'user@example.com',
          company: 'Example Inc',
          startsAt: '2020-01-01',
          expiresAt: '2022-01-01',
          activatedAt: '2021-01-02',
          lastSync: null,
          usersInLicenseCount: 100,
          billableUsersCount: 50,
          maximumUserCount: 50,
          usersOverLicenseCount: 0,
        },
        errors: [],
      },
    },
  },
};
