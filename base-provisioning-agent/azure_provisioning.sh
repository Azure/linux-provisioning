#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

set -euo pipefail

VMID_FILE="/var/local/vmid"
REPORT_READY_SCRIPT="/usr/local/report_ready.py"

run_provisioning () {
    echo "Reporting ready to Azure"
    python3 "$REPORT_READY_SCRIPT"

    local NEW_HOSTNAME=$(curl \
        -H 'metadata: true' \
        'http://169.254.169.254/metadata/instance/compute/name?api-version=2019-06-01&format=text')
    echo "Setting new hostname to $NEW_HOSTNAME"
    hostnamectl set-hostname "$NEW_HOSTNAME"

    echo "Provisioning complete"
}

echo "Running conditional Azure Linux provisioning"

CURRENT_VMID=$(curl \
    -H 'metadata: true' \
    'http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-06-01&format=text')

# If the vmId marker file does not exist at all, then this means
# that provisioning was never run. In that case, run provisioning.
if [[ ! -f "$VMID_FILE" ]]; then
    echo "No vmid file, running provisioning"
    run_provisioning
    echo "$CURRENT_VMID" > "$VMID_FILE"
    exit
fi

# If the vmId file exists, check to see if the recorded vmId is
# matching the current actual vmId of the machine. If they are
# the same, then this means that provisioning has already run for
# this VM. But if the vmIds do not match, then we need to treat
# this boot as requiring provisioning steps.
PREVIOUS_VMID=$(cat "$VMID_FILE")
echo "Previous vmId: $PREVIOUS_VMID"
echo "Current vmId: $CURRENT_VMID"
if [[ "$PREVIOUS_VMID" != "$CURRENT_VMID" ]]; then
    echo "vmId does not match, running provisioning"
    run_provisioning
    echo "$CURRENT_VMID" > "$VMID_FILE"
else
    echo "Matching vmIds, not running provisioning"
fi
