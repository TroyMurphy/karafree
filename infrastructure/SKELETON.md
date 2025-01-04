# Terraform Skeleton Project

A base terraform Azure DevOps pipeline to start terraforming quickly.

## Prerequisites

Assumes you've already [bootstrapped terraform](BOOTSTRAPPING.md) and have the following:

1. Resource group with a terraform state storage account inside.
1. Service principal client and secret in 1password.
1. macOS, Linux or WSL2 under Windows.

## Getting Started

* `Source`: `skeleton/` directory
* `Target`: Azure DevOps project/git repository of the new infrastructure

1. From `source`, copy the `infrastructure` directory into the git repository where your new infrastructure as code will live
1. From `source`, merge the contents of `.gitignore` into `target` to prevent non-code terraform files from being committed into git
1. In the `target` git repository, edit `infrastructure/pipelines/infrastructure.yml` and update all the values to those used during bootstrapping
    * Initially you'll be developing for `dev` and you can comment out the other environments until they will be used
1. Create a new `Infrastructure` pipeline in the `target` Azure DevOps project which runs `infrastructure/pipelines/infrastructure.yml`

## Developing With Terraform

Depending on how complicated your infrastructure is, you might be running terraform many _many_ times until your code deploys what you expect it to. Ideally you'll want to avoid developing your code using the Azure DevOps pipeline as the cycle time from code to pipeline execution is very slow as the pipeline performs multiple redundant steps with multiple approval steps.

Instead, use the pipeline's service principal and develop the infrastructure code on your device. This way you'll have all the permission issues ironed out before it hits the build pipeline.

Terraform's [AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) provider has many ways to authenticate with Azure. We'll be using our [service principal with a secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret) which is the same way that your Azure DevOps pipeline will authenticate.

1. Our skeleton project probably has an outdated `azurerm` version number and you'll want to use the latest version for your new infrastructure. Find all files called `provider.tf` under `infrastructure/terraform/` and make the following change (there will be one file per environment):

    1. Follow the path `terraform.required_providers.azurerm.version` and change `version = "..."` to the [latest version](https://registry.terraform.io/providers/hashicorp/azurerm/latest) of the `azurerm` provider.

        ```hcl
        terraform {
          required_providers {
            azurerm = {
              source  = "hashicorp/azurerm"
              version = "..."  # <------- Here
            }
          }

          ...
        ```

1. Change directory to `infrastructure/terraform/example-dev/`

1. We'll need environment files for `dev` and you'll want to make sure that the service principal secret isn't automatically saved to the local [`.terraform` directory](https://developer.hashicorp.com/terraform/language/settings/backends/configuration#credentials-and-sensitive-data), shell history or in a file you created.
    * 1Password 8 supports the CLI, here's the [guide](https://developer.1password.com/docs/cli/get-started/) for setting it up if you don't have it already.
    * If you're not using a secret store for credentials, please manage secret credentials appropriately. You also won't be able to copy and paste commands from this document.

1. Start with 1Password's CLI and check your account is displayed.

    ```bash
    op account list
    ```

1. Create a file called `.env.dev.conf` in the `infrastructure/terraform/example-dev` directory. You can find the values for `dev` in `infrastructure/pipelines/infrastructure.yml`. This is terraform's [backend configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration).

    ```ini
    # .env.dev.conf: Backend configuration for terraform.
    # This file should NEVER be committed into git.

    # terraformStorageResourceGroup
    resource_group_name=""
    # terraformStorageAccount
    storage_account_name=""
    # terraformStorageContainer
    container_name=""
    # terraformStorageStateKey
    key=""
    ```

1. Create a file called `.env.dev` in the `infrastructure/terraform/example-dev` directory. You'll need to adjust the `op://[...]` URI based on where the [secret is stored](https://developer.1password.com/docs/cli/secrets-reference-syntax/) in 1Password. Values are in the same place as previous step.

    ```bash
    # .env.dev: Azure Service Principal authentication for terraform.
    # This file should NEVER be committed into git.

    ARM_TENANT_ID=""
    ARM_SUBSCRIPTION_ID=""
    # Client Id: Search Azure Entra ID for the name of the service principal, app registrations, overview, "Application (client) ID" field
    ARM_CLIENT_ID="op://private/ltdeftweb-sp-azuredevops-dev-01/client_id"
    # Client secret: In the "Certificates & secrets blade" of the service principal
    ARM_CLIENT_SECRET="op://private/ltdeftweb-sp-azuredevops-dev-01/client_secret"
    ```

1. Check your `git status` and really make sure that `.env.dev.conf` and `.env.dev` stays very far away from the git repository.

1. Repeat the previous step.

1. Create the storage account container if it doesn't exist as terraform won't create it for you:

    ```bash
    STORAGE_ACCOUNT_NAME="" # account-name is storage_account_name from .env.dev.conf
    CONTAINER_NAME=""       # name is container_name from .env.dev.conf

    az storage container create --auth-mode login \
                                --account-name "$STORAGE_ACCOUNT_NAME" \
                                --name "$CONTAINER_NAME" \
                                --public-access off

    # If the command fails and you get an error "The request may be blocked...":
    # * Are you a member of the appropriate DevOps Azure Entra ID group?
    # * Does the appropriate DevOps Azure Entra ID group have Owner permission over the resource group?
    # * Try signing in and out again then run the command again.
    #   az account clear
    #   az login
    ```

1. Initialize the backend:

    ```bash
    op run --env-file="./.env.dev" -- terraform init -backend-config=".env.dev.conf"
    ```

1. Review the `example_dev.tf` file and start making changes.

1. You can now write your code and perform the typical terraform steps:

    ```bash
    # Generate plan
    op run --env-file="./.env.dev" -- terraform plan -out=dev.plan
    # Remember to review the plan before applying
    op run --env-file="./.env.dev" -- terraform apply dev.plan
    ```

After you've committed your changes into git you can run the infrastructure pipeline and terraform will use the same state file (because you've used the same values in the `.env.dev.conf`) resulting in the same infrastructure changes.

## Permissions

If you're using terraform to assign a role assignment to a resource, your terraform service principal might not have the correct privileges to do so which will result in a 403 from the Azure API.

On the resource group, you can assign the role `Role Based Access Control Administrator` to the service principal and constrain it to the role which terraform will be giving to another user/group. For example if terraform is assigning a key vault permission to a user, the constraint could be `Key Vault Secrets User`. Document the manual steps you took in your bootstrapping terraform guide.

