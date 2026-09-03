#!/usr/bin/env bash
set -euo pipefail

# Run after staging and production resource groups exist.
# Usage:
#   ./infra/setup-github-oidc.sh <github-owner> <github-repo> <staging-rg> <production-rg>

GITHUB_OWNER="${1:?GitHub owner required}"
GITHUB_REPO="${2:?GitHub repository name required}"
STAGING_RG="${3:?staging resource group required}"
PRODUCTION_RG="${4:?production resource group required}"
APP_NAME="taskflow-github-actions"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
APP_OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)
az ad sp create --id "$APP_ID" >/dev/null

cat > /tmp/taskflow-staging-fed.json <<EOF
{
  "name": "github-staging",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_OWNER}/${GITHUB_REPO}:environment:staging",
  "description": "GitHub Actions staging environment",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

cat > /tmp/taskflow-production-fed.json <<EOF
{
  "name": "github-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_OWNER}/${GITHUB_REPO}:environment:production",
  "description": "GitHub Actions production environment",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters /tmp/taskflow-staging-fed.json
az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters /tmp/taskflow-production-fed.json

SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

for RG in "$STAGING_RG" "$PRODUCTION_RG"; do
  RG_ID=$(az group show --name "$RG" --query id -o tsv)
  STORAGE_ID=$(az storage account list --resource-group "$RG" --query '[0].id' -o tsv)

  # Contributor allows Front Door cache purge and resource operations for this learning project.
  az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role Contributor \
    --scope "$RG_ID" >/dev/null

  # Data-plane permission required by `az storage blob upload-batch --auth-mode login`.
  az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "$STORAGE_ID" >/dev/null
done

echo
echo "GitHub OIDC application created. Add these GitHub Environment variables to BOTH staging and production:"
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
