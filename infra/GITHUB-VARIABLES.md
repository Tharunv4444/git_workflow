# GitHub Environment variables

Create two GitHub Environments: `staging` and `production`.

Add these variables to both environments:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `STORAGE_ACCOUNT`
- `RESOURCE_GROUP`
- `FRONTDOOR_PROFILE`
- `FRONTDOOR_ENDPOINT`

Example staging values:

```text
STORAGE_ACCOUNT=<your-staging-storage-account>
RESOURCE_GROUP=rg-taskflow-staging
FRONTDOOR_PROFILE=taskflow-staging-afd
FRONTDOOR_ENDPOINT=taskflow-staging-endpoint
```

Example production values:

```text
STORAGE_ACCOUNT=<your-production-storage-account>
RESOURCE_GROUP=rg-taskflow-production
FRONTDOOR_PROFILE=taskflow-production-afd
FRONTDOOR_ENDPOINT=taskflow-production-endpoint
```

The first three values are printed by `infra/setup-github-oidc.sh`.
