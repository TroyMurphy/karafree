# SERVICE_PRINCIPAL_NAME=ltdeftweb-sp-azuredevops-dev-01
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
