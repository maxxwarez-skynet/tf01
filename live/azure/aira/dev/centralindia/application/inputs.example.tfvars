state_backend = {
  resource_group_name  = "YOUR-STATE-RESOURCE-GROUP"
  storage_account_name = "YOURUNIQUESTATEACCOUNT"
  container_name       = "tfstate"
}
ssh_public_key = "REPLACE_WITH_OPENSSH_PUBLIC_KEY"
admin_cidrs    = [] # Populate with your actual administrative IPv4 CIDRs.

ubuntu_image_version = "REPLACE_WITH_PINNED_MARKETPLACE_VERSION"
