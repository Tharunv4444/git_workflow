# TaskFlow 🚀 — Azure Edition

A small team task-manager web app used to learn a real-world CI/CD flow:

```text
feature branch -> Pull Request -> Tests -> Lead review -> merge to master
                                                     |
                                                     v
                                      Azure Storage (staging)
                                                     |
                                                     v
                                      Azure Front Door (staging)
                                                     |
                                             production approval
                                                     |
                                                     v
                                      Azure Storage (production)
                                                     |
                                                     v
                                      Azure Front Door (production)
```

## Application

Open `index.html` locally. Tasks are stored in browser localStorage.

## Tests

```bash
node --test tests/
```

## Azure infrastructure

The old AWS S3, CloudFront, OAC, IAM trust and IAM permission JSON files were removed.

Azure replacements:

- `infra/setup-azure.sh` — creates Azure Storage Static Website + Azure Front Door Standard.
- `infra/setup-github-oidc.sh` — creates Microsoft Entra application/federated credentials for GitHub OIDC and assigns Azure permissions.
- `infra/GITHUB-VARIABLES.md` — variables required by GitHub environments.
- `.github/workflows/ci-cd.yml` — tests PRs and deploys `master` to staging then production.

## 1. Login to Azure

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

## 2. Create staging

Storage account names must be globally unique and contain only lowercase letters and numbers.

```bash
./infra/setup-azure.sh staging rg-taskflow-staging centralindia <unique-staging-storage-name>
```

## 3. Create production

```bash
./infra/setup-azure.sh production rg-taskflow-production centralindia <unique-production-storage-name>
```

## 4. Configure GitHub OIDC

```bash
./infra/setup-github-oidc.sh <github-owner> <github-repo> rg-taskflow-staging rg-taskflow-production
```

The script prints `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`.

## 5. Configure GitHub environments

Create `staging` and `production` under GitHub repository Settings -> Environments.

Add the variables listed in `infra/GITHUB-VARIABLES.md`. Use the staging resource names in `staging` and production resource names in `production`.

For a manual production gate, add required reviewers to the `production` GitHub Environment if your GitHub plan/repository settings support it.

## 6. CI/CD behavior

- Pull request to `master`: tests only.
- Merge/push to `master`: tests -> staging deployment -> Front Door cache purge -> production environment -> production deployment -> cache purge.
