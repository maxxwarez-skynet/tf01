state_backend = {
  resource_group_name  = "YOUR-STATE-RESOURCE-GROUP"
  storage_account_name = "YOURUNIQUESTATEACCOUNT"
  container_name       = "tfstate"
}
key_vault_name = "YOUR-UNIQUE-VAULT-NAME"
# Set TF_VAR_mysql_password from your secret manager; do not put it here.
