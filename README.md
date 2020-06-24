# Azure Linux Provisioning

![](https://github.com/Azure/linux-provisioning/workflows/Base%20provisioning%20agent/badge.svg)

## Base/boilerplate provisioning agent

### What is this?

This is the least amount of work that a provisioning agent has to do to bring a VM up in Azure. This is meant to provide users with an alternative to other supported provisioning agents in Azure Linux VMs ([walinuxagent](https://github.com/Azure/WALinuxAgent) and [cloud-init](https://github.com/canonical/cloud-init)).

### What can you do with this?

Use it as-is, or fork/clone it and develop your own provisioning agent on top of the existing code/boilerplate.

### When would you want this?

If you have decided that you can't use either the walinuxagent or cloud-init for provisioning, this solution could provide you with the base requirements for provisioning an Azure Linux VM.

### Requirements

This boilerplate assumes that you can use python3 (for the report ready script) and systemd (for scheduling and coordinating the provisioning) in your image. If you cannot use either of these, then it is recommended to read and understand the basic code and port it to your platform of choice.

### Running tests locally

If you want to run the end-to-end tests that the CI pipeline runs, you need to first setup your environment and SSH key:

```
$ ./tests/ssh_key_setup.sh
```

This will create `~/.ssh/linuxpa` and `~/.ssh/linuxpa.pub` key pair if it doesn't exist. Then in your current subscription (`az account show`) it will create (if it doesn't exist) a resource group named `linuxpa`, a key vault named `linuxpa` and then upload the private key to a key vault secret.

This key is retrieved in `tests/end_to_end.sh` to ensure that the runner (or in the case of running locally, your local machine) can SSH into the target VMs to validate.

Then to run the tests, you can do the following:

```
$ GITHUB_WORKSPACE=<local_repo_path> \
    AZ_USERNAME="<sp_id>" \
    AZ_PASSWORD="<sp_secret>" \
    AZ_TENANT="<tenant_id>" \
    AZ_SUBSCRIPTION="<subscription_id>" \
    ./tests/end_to_end.sh
```

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
