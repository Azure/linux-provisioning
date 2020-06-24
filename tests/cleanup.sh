#!/bin/bash

set -euo pipefail

RESOURCE_GROUP_TAG="linuxpa=test"

echo "$(date) - Running cleanup"

echo "$(date) - Logging into the Azure CLI"
az login \
    --service-principal \
    --username "$AZ_USERNAME" \
    --password "$AZ_PASSWORD" \
    --tenant "$AZ_TENANT"
az account set --subscription "$AZ_SUBSCRIPTION"

az group list \
    --tag "$RESOURCE_GROUP_TAG" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting resource group {} && az group delete --no-wait --yes --name {}"

echo "$(date) - Completed cleanup"
