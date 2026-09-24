terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "registry.opentofu.org/hashicorp/azurerm"
      version = "~> 4.67.0"
    }
  }
}
