#!/bin/bash

set -euo pipefail

RESOURCE_NAME="linuxpa"
LOCATION="eastus"
KEY_PATH="~/.ssh/${RESOURCE_NAME}"
KEY_PATH="${KEY_PATH/#\~/$HOME}"

if [[ ! -f "$KEY_PATH" ]]; then
    ssh-keygen -t rsa -f "$KEY_PATH" -q -P ""
fi

az group show --name "$RESOURCE_NAME" ||
    az group create \
        --location "$LOCATION" \
        --name "$RESOURCE_NAME"

az keyvault show --name "$RESOURCE_NAME" ||
    az keyvault create \
        --resource-group "$RESOURCE_NAME" \
        --name "$RESOURCE_NAME"

az keyvault secret set \
    --vault-name "$RESOURCE_NAME" \
    --name "$RESOURCE_NAME" \
    --file "$KEY_PATH"
