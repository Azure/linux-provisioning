#!/bin/bash

set -euo pipefail

RESOURCE_GROUP_TAG="linuxpa=test"
RESOURCE_NAME="linuxpa${RANDOM}"
IMAGE="debian:debian-10:10:latest"
SSH_DIR="~/.ssh"
SSH_DIR="${SSH_DIR/#\~/$HOME}"
SSH_KEY_FILE="${SSH_DIR}/linuxparunner"
SSH_PUB_KEY_FILE="${SSH_KEY_FILE}.pub"
LOCATION="eastus"

echo "$(date) - Running end to end tests"
echo "$(date) - Using resource name '$RESOURCE_NAME'"

echo "$(date) - Logging into the Azure CLI"
az login \
    --service-principal \
    --username "$AZ_USERNAME" \
    --password "$AZ_PASSWORD" \
    --tenant "$AZ_TENANT"
az account set --subscription "$AZ_SUBSCRIPTION"

echo "$(date) - Retrieving the SSH key"
mkdir -p "$SSH_DIR"
az keyvault secret show \
    --vault-name linuxpa \
    --name linuxpa \
    --query value -o tsv > "$SSH_KEY_FILE"
chmod 600 "$SSH_KEY_FILE"
ssh-keygen -y -f "$SSH_KEY_FILE" > "$SSH_PUB_KEY_FILE"

echo "$(date) - Creating the resource group"
az group create \
    --location "$LOCATION" \
    --name "$RESOURCE_NAME" \
    --tags "$RESOURCE_GROUP_TAG"

echo "$(date) - Creating the network security group"
az network nsg create \
    --name "$RESOURCE_NAME" \
    --resource-group "$RESOURCE_NAME"

echo "$(date) - Creating network security group rule"
az network nsg rule create \
    --name "$RESOURCE_NAME" \
    --nsg-name "$RESOURCE_NAME" \
    --priority 100 \
    --resource-group "$RESOURCE_NAME" \
    --access Allow \
    --direction Inbound \
    --source-address-prefixes $(curl ipinfo.io/ip) \
    --destination-port-ranges 22

echo "$(date) - Creating vnet"
az network vnet create \
    --name "$RESOURCE_NAME" \
    --resource-group "$RESOURCE_NAME"

echo "$(date) - Creating subnet"
az network vnet subnet create \
    --name "$RESOURCE_NAME" \
    --vnet-name "$RESOURCE_NAME" \
    --resource-group "$RESOURCE_NAME" \
    --address-prefixes "10.0.0.0/24" \
    --network-security-group $(az network nsg show \
        --resource-group "$RESOURCE_NAME" \
        --name "$RESOURCE_NAME" --query id -o tsv)

echo "$(date) - Creating the base VM"
az vm create \
    --name "$RESOURCE_NAME" \
    --resource-group "$RESOURCE_NAME" \
    --location "$LOCATION" \
    --ssh-key-value "$SSH_PUB_KEY_FILE" \
    --public-ip-address-dns-name "$RESOURCE_NAME" \
    --image "$IMAGE" \
    --vnet-name "$RESOURCE_NAME" \
    --subnet "$RESOURCE_NAME" \
    --nsg "$RESOURCE_NAME"

echo "$(date) - Removing walinux agent from VM"
ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "sudo apt remove -y waagent &&
    sudo rm -rf /var/lib/waagent /etc/waagent.conf /var/log/waagent.log"

echo "$(date) - Copying provisioning files"
scp \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "$GITHUB_WORKSPACE/base-provisioning-agent/azure_provisioning.sh" \
    "${RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com":~
scp \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "$GITHUB_WORKSPACE/base-provisioning-agent/azure-provisioning.service" \
    "${RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com":~
scp \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "$GITHUB_WORKSPACE/base-provisioning-agent/report_ready.py" \
    "${RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com":~
ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "sudo mv ~/azure_provisioning.sh /usr/local &&
    sudo mv ~/azure-provisioning.service /etc/systemd/system &&
    sudo mv ~/report_ready.py /usr/local"

echo "$(date) - Enabling the systemd unit"
ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "sudo systemctl enable azure-provisioning.service"

echo "$(date) - Creating image from base VM"
az vm deallocate \
    --resource-group "$RESOURCE_NAME" \
    --name "$RESOURCE_NAME"
az vm generalize \
    --resource-group "$RESOURCE_NAME" \
    --name "$RESOURCE_NAME"
az image create \
    --resource-group "$RESOURCE_NAME" \
    --source "$RESOURCE_NAME" \
    --location "$LOCATION" \
    --name "$RESOURCE_NAME"
IMAGE_ID=$(az image show \
    --resource-group "$RESOURCE_NAME" \
    --name "$RESOURCE_NAME" \
    --query id -o tsv)

echo "$(date) - Deleting base VM"
az vm delete \
    --resource-group "$RESOURCE_NAME" \
    --name "$RESOURCE_NAME" \
    --yes

NEW_RESOURCE_NAME="${RESOURCE_NAME}new"
echo "$(date) - Creating VM from image"
az vm create \
    --resource-group "$RESOURCE_NAME" \
    --name "$NEW_RESOURCE_NAME" \
    --location "$LOCATION" \
    --ssh-key-value "$SSH_PUB_KEY_FILE" \
    --public-ip-address-dns-name "$NEW_RESOURCE_NAME" \
    --image "$IMAGE_ID" \
    --vnet-name "$RESOURCE_NAME" \
    --subnet "$RESOURCE_NAME" \
    --nsg "$RESOURCE_NAME" \
    --enable-agent false

echo "$(date) - Validating provisioning"
RESULT=$(ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${NEW_RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "systemctl show --property Result azure-provisioning.service")
echo "$(date) - Provisioning unit result: '$RESULT'"
if [[ "$RESULT" != "Result=success" ]]; then
    echo "$(date) - Failed provisioning with bad result"
    exit 1
fi

JOURNAL_LOGS=$(ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${NEW_RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "sudo journalctl -u azure-provisioning.service")
echo "$(date) - Dumping journal logs to validate provisioning complete"
echo "$JOURNAL_LOGS"
if [[ ! "$JOURNAL_LOGS" == *"Provisioning complete"* ]]; then
    echo "$(date) - No provisioning complete log message"
    exit 1
fi

echo "$(date) - Rebooting VM to validate the no provisioning scenario"
ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${NEW_RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "sudo reboot"
sleep 120
RESULT=$(ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${NEW_RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "systemctl show --property Result azure-provisioning.service")
echo "$(date) - Provisioning unit result: '$RESULT'"
if [[ "$RESULT" != "Result=success" ]]; then
    echo "$(date) - Failed second boot with bad result"
    exit 1
fi

JOURNAL_LOGS=$(ssh \
    -i "$SSH_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    "${NEW_RESOURCE_NAME}.${LOCATION}.cloudapp.azure.com" \
    "sudo journalctl -u azure-provisioning.service")
echo "$(date) - Dumping journal logs to validate no provisioning"
echo "$JOURNAL_LOGS"
if [[ ! "$JOURNAL_LOGS" == *"Matching vmIds, not running provisioning"* ]]; then
    echo "$(date) - Expected provisioning not to run"
    exit 1
fi

echo "$(date) - All tests succeeded"
