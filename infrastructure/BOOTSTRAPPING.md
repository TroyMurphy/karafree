# Bootstrapping Terraform

## Guidelines

Develop your infrastructure as code as if you are deploying to another company's Azure tenant who gives you limited access and is _very_ security conscious.

## Preamble

You'll need `bash` and the Azure CLI `az` to run these commands without adapting them.

We'll be creating the following:

* Resource Group: To hold the app's resources and terraform's state.
* Storage Account: Where Terraform's state file goes.
* Service Principal: Service connection for Azure DevOps pipelines.
* Azure User Group: For you to manage terraform's resources.

## Azure

1. Choose a naming scheme (there's a deft toolkit for this called `naming`). In this example the client is `Lantern` (lt) and we're deploying an app called `Deft Web` (deftweb).

1. Set the default Azure DevOps organization and subscription.

    ```bash
    az devops configure --defaults organization=https://dev.azure.com/devfacto/
    az account list --output table
    az account set --subscription "..." # SubscriptionId
    ```

1. If one doesn't exist already, create an Azure group for humans who are managing the Azure resources.

   ```bash
   az ad group create --display-name "ltdeftweb-grp-devops-01" --mail-nickname "ltdeftweb-grp-devops-01"
   ```

1. For development purposes, make sure that the DevOps group (`ltdeftweb-grp-devops-01`) has `Owner` permission on the resource group. In environments outside development, `Contributor` should be enough.

1. Add yourself to the aforementioned DevOps group.

1. Choose a name for the Azure resource group and create it if it doesn't exist.

    ```bash
    az group create --location "Canada Central" --name "ltdeftweb-rg-cnc-dev-01"
    ```

1. Create a service principal in Azure Entra ID and grant it `contributor` access to the resource group.

    ```bash
    SERVICE_PRINCIPAL_NAME=ltdeftweb-sp-azuredevops-dev-01
    az ad sp create-for-rbac --name "$SERVICE_PRINCIPAL_NAME" --years 10

    # You'll need the output of this command in the next step!
    ```

1. Create an entry in 1password (in the project's vault) as you'll need these later:

    * Name: `ltdeftweb-sp-azuredevops-dev-01`
    * Text field called `client_id`, value is from the output of the previous command, `appId` field
    * Password field called `client_password`, value is from the output of the previous command, `password` field

1. Create the service connection in Azure DevOps.

    ```bash
    ADO_SERVICE_CONNECTION_NAME=ltdeftweb-sp-azuredevops-dev-01
    ADO_PROJECT_NAME=deft # This is the name of the project in Azure DevOps

    AZURE_APP_REGISTRATION_ID=... # This is appId from the previous step

    AZURE_TENANT_ID=$(az account show --output tsv --query "tenantId")
    AZURE_SUBSCRIPTION_ID=$(az account show --output tsv --query "id")
    AZURE_SUBSCRIPTION_NAME=$(az account show --output tsv --query "name")

    # When you run the next command, it'll ask for the password (from the previous step)
    # You can also specify the service principal key (password) using the AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY environment variable

    az devops service-endpoint azurerm create --name "$ADO_SERVICE_CONNECTION_NAME"                        \
                                              --project "$ADO_PROJECT_NAME"                                \
                                              --azure-rm-tenant-id "$AZURE_TENANT_ID"                      \
                                              --azure-rm-subscription-id "$AZURE_SUBSCRIPTION_ID"          \
                                              --azure-rm-subscription-name "$AZURE_SUBSCRIPTION_NAME"      \
                                              --azure-rm-service-principal-id "$AZURE_APP_REGISTRATION_ID"
    ```

1. Create the storage account for terraform's state file in the resource group for the project.
    * Choose these settings during account creation
        * Performance: Standard (general-purpose v2)
        * Access tier: Hot
        * Redundancy: LRS
        * Allow enabling anonymous access on individual containers: No
        * Enable storage account key access: No (we're using IAM)
        * Enable infrastructure encryption: Yes
        * Minimum TLS version: >= 1.2 (higher the better)

    ```bash
    SUBSCRIPTION_ID=$(az account show --output tsv --query "id")
    RESOURCE_GROUP_NAME=ltdeftweb-rg-cnc-dev-01
    STORAGE_ACCOUNT_NAME=ltdeftwebsttfcncdev01

    az storage account create                  \
      --subscription "$SUBSCRIPTION_ID"        \
      --resource-group "$RESOURCE_GROUP_NAME"  \
      --name "$STORAGE_ACCOUNT_NAME"           \
      --kind StorageV2                         \
      --sku Standard_LRS                       \
      --https-only true                        \
      --allow-blob-public-access false         \
      --allow-shared-key-access false          \
      --encryption-services blob               \
      --require-infrastructure-encryption true \
      --min-tls-version TLS1_2
    ```

1. Assign roles to the storage account. `AZURE_DEVOPS_GROUP_NAME` is the name of the group in the first steps.

    * Default permissions are:
        * Resource group: Contributor to terraform's service principal
        * Resource group: Contributor to DevOps group
        * Storage account: Storage Blob Data Contributor to terraform's service principal
        * Storage account: Storage Blob Data Contributor to DevOps group

    ```bash
    SERVICE_PRINCIPAL_NAME=ltdeftweb-sp-azuredevops-dev-01
    SERVICE_PRINCIPAL_ID=$(az ad sp list --filter "displayname eq '$SERVICE_PRINCIPAL_NAME'" --query '[].appId' --output tsv)

    AZURE_DEVOPS_GROUP_NAME=ltdeftweb-grp-devops-01
    AZURE_DEVOPS_GROUP_ID=$(az ad group list --filter "displayname eq '$AZURE_DEVOPS_GROUP_NAME'" --query '[].id' --output tsv)

    SUBSCRIPTION_ID=$(az account show --output tsv --query "id")
    RESOURCE_GROUP_NAME=ltdeftweb-rg-cnc-dev-01
    STORAGE_ACCOUNT=ltdeftwebsttfcncdev01

    az role assignment create --assignee "$SERVICE_PRINCIPAL_ID" \
                              --role Contributor \
                              --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME"

    az role assignment create --assignee "$AZURE_DEVOPS_GROUP_ID" \
                              --role Contributor \
                              --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME"

    az role assignment create --assignee "$SERVICE_PRINCIPAL_ID" \
                              --role "Storage Blob Data Contributor" \
                              --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"

    az role assignment create --assignee "$AZURE_DEVOPS_GROUP_ID" \
                              --role "Storage Blob Data Contributor" \
                              --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
    ```

### Extra Permissions/Steps

If terraform to apply role assignments to resources, it needs permission to assign those roles. While developing your terraform infrastructure as code you might have to manually set this permission on the resource group (typically `Role Based Access Control Administrator` restricted to the role you're applying).

For example, if terraform is assigning the role `Key Vault Secrets User` to a Key Vault for a user or group, you'll need to add additional permissions on the resource group: `Role Based Access Control Administrator` to terraform's service principal constrained to the role it will be assigning (`Key Vault Secrets User`). Always constrain the role otherwise terraform can elevate privileges when it shouldn't.

Here's a great place to document the final permission list:

Where|Who|Role|Notes
---|---|---|---
Resource Group|DevOps Team|`Contributor`|You'll need this to do your job
Resource Group|Terraform Service Principal|`Contributor`|Terraform will need this to manage resources in the resource group
Terraform State Storage Account|Terraform Service Principal|`Storage Blob Data Contributor`|Terraform needs this to manage its state file
Terraform State Storage Account|DevOps Team|`Storage Blob Data Contributor`|You'll need this to view the contents of the storage account when things go wrong

**Example** extra permissions:

Where|Who|Role|Notes
---|---|---|---
Resource Group|Terraform Service Principal|`Role Based Access Control Administrator`|Constrained to the role `Key Vault Secrets User` and `Key Vault Certificates Officer` and allows terraform to assign resources permissions to the key vault

## Azure DevOps

You'll want to perform these under your target Azure DevOps project.

1. Create the pipeline environments (if they don't exist already), you'll _always_ want an approval for every environment as terraform should never run automatically.

    * Environments depending on the application, usually you'll want ones for Dev, QA/UAT and Prod:

        * `Terraform Dev Plan`
        * `Terraform Dev Apply`
        * `Terraform QA Plan`
        * `Terraform QA Apply`
        * `Terraform Prod Plan`
        * `Terraform Prod Apply`

    * For each of the above environments:
        1. Azure DevOps, Pipelines, Environments
        1. `New environment` button
        1. `Approval and checks tab`
            * _Always have an approval on the Apply environment_. Otherwise Terraform will automatically make any changes outlined in the plan including **deleting everything**.
        1. Add an approval for `[project]\Build Administrators`
        1. Choose the 3 dots at the top right, `Security`
        1. Give `[project]\Project Administrators` the `Administrator` role
            * Otherwise only you and global administrators can make changes to this environment.

    * Ensure that you gave the appropriate group `Administrator` access to the environments you just created.
    * All environments have an approval right?

## Git Repository

1. See [Terraform Skeleton Project](SKELETON.md) for next steps.

