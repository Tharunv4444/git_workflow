#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./infra/setup-azure.sh <environment> <resource-group> <location> <storage-account>
# Example:
#   ./infra/setup-azure.sh staging rg-taskflow-staging centralindia taskflowstg12345

ENVIRONMENT="${1:?environment required: staging or production}"
RESOURCE_GROUP="${2:?resource group required}"
LOCATION="${3:?Azure location required, e.g. centralindia}"
STORAGE_ACCOUNT="${4:?globally unique storage account name required}"

AFD_PROFILE="taskflow-${ENVIRONMENT}-afd"
AFD_ENDPOINT="taskflow-${ENVIRONMENT}-endpoint"
ORIGIN_GROUP="taskflow-${ENVIRONMENT}-origin-group"
ORIGIN_NAME="taskflow-${ENVIRONMENT}-storage-origin"
ROUTE_NAME="taskflow-${ENVIRONMENT}-route"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access true

az storage blob service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --static-website \
  --index-document index.html \
  --404-document index.html \
  --auth-mode login

WEB_URL=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'primaryEndpoints.web' -o tsv)
ORIGIN_HOST=$(printf '%s' "$WEB_URL" | sed -E 's#^https?://##; s#/$##')

az afd profile create \
  --profile-name "$AFD_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Standard_AzureFrontDoor

az afd endpoint create \
  --endpoint-name "$AFD_ENDPOINT" \
  --profile-name "$AFD_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --enabled-state Enabled

az afd origin-group create \
  --origin-group-name "$ORIGIN_GROUP" \
  --profile-name "$AFD_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --probe-request-type HEAD \
  --probe-protocol Https \
  --probe-interval-in-seconds 60 \
  --probe-path /

az afd origin create \
  --origin-name "$ORIGIN_NAME" \
  --origin-group-name "$ORIGIN_GROUP" \
  --profile-name "$AFD_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --host-name "$ORIGIN_HOST" \
  --origin-host-header "$ORIGIN_HOST" \
  --http-port 80 \
  --https-port 443 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled \
  --certificate-name-check-enabled true

az afd route create \
  --route-name "$ROUTE_NAME" \
  --endpoint-name "$AFD_ENDPOINT" \
  --profile-name "$AFD_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --origin-group "$ORIGIN_GROUP" \
  --supported-protocols Http Https \
  --patterns-to-match '/*' \
  --forwarding-protocol HttpsOnly \
  --https-redirect Enabled \
  --link-to-default-domain Enabled

AFD_HOST=$(az afd endpoint show \
  --endpoint-name "$AFD_ENDPOINT" \
  --profile-name "$AFD_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --query hostName -o tsv)

echo
echo "Azure environment created successfully."
echo "Environment:        $ENVIRONMENT"
echo "Resource group:     $RESOURCE_GROUP"
echo "Storage account:    $STORAGE_ACCOUNT"
echo "Static website:     $WEB_URL"
echo "Front Door profile: $AFD_PROFILE"
echo "Front Door endpoint:$AFD_ENDPOINT"
echo "Front Door URL:     https://$AFD_HOST"
