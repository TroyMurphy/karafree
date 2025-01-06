SUBSCRIPTION_ID=8aa6bce6-a640-48aa-a328-e1aed1c86155

az storage account create \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$STORAGE_ACCOUNT_NAME" \
  --kind StorageV2 \
  --sku Standard_LRS \
  --https-only true \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --encryption-services blob \
  --require-infrastructure-encryption true \
  --min-tls-version TLS1_2
