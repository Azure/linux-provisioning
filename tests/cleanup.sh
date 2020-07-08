#!/bin/bash

set -euo pipefail

RESOURCE_GROUP_NAME="linuxpa-testing"

echo "$(date) - Running cleanup"

echo "$(date) - Logging into the Azure CLI"
az login \
    --service-principal \
    --username "$AZ_USERNAME" \
    --password "$AZ_PASSWORD" \
    --tenant "$AZ_TENANT" > /dev/null
az account set --subscription "$AZ_SUBSCRIPTION"

az vm list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting VM {} && az vm delete --resource-group ${RESOURCE_GROUP_NAME} --yes --name {}"

az disk list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting disk {} && az disk delete --resource-group ${RESOURCE_GROUP_NAME} --yes --name {}"

az image list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting image {} && az image delete --resource-group ${RESOURCE_GROUP_NAME} --name {}"

az network nic list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting nic {} && az network nic delete --resource-group ${RESOURCE_GROUP_NAME} --name {}"

az network public-ip list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting public IP {} && az network public-ip delete --resource-group ${RESOURCE_GROUP_NAME} --name {}"

az network vnet list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting vnet {} && az network vnet delete --resource-group ${RESOURCE_GROUP_NAME} --name {}"

az network nsg list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query '[].name' -o tsv |
    xargs -n 1 -I{} \
        /bin/bash -c \
        "echo Deleting nsg {} && az network nsg delete --resource-group ${RESOURCE_GROUP_NAME} --name {}"

RESOURCE_LIST=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" -o table)
if [[ -n "$RESOURCE_LIST" ]]; then
    echo "$(date) - Unexpected resources in test resource group"
    echo "$RESOURCE_LIST"
    exit 1
fi

echo "$(date) - Successfully completed cleanup"
