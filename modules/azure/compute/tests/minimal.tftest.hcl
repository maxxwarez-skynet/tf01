mock_provider "azurerm" {
  mock_resource "azurerm_public_ip" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/test" }
  }
  mock_resource "azurerm_network_interface" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/test" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/test" }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/test" }
  }
}
variables {
  image               = { publisher = "Canonical", offer = "ubuntu-24_04-lts", sku = "server", version = "24.04.202409120" }
  name                = "aira-test"
  resource_group_name = "rg-test"
  location            = "centralindia"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/test/subnets/test"
  ssh_public_key      = file("tests/admin.pub")
  admin_cidrs         = ["203.0.113.10/32"]
}
run "minimal_public_vm" {
  command = plan
  assert {
    condition     = azurerm_linux_virtual_machine.this.disable_password_authentication && azurerm_linux_virtual_machine.this.zone == "1"
    error_message = "VM must use SSH keys and the selected single zone."
  }
  assert {
    condition     = azurerm_public_ip.this.sku == "Standard" && azurerm_public_ip.this.allocation_method == "Static"
    error_message = "Each VM must have its own static Standard public IP."
  }
  assert {
    condition     = length([for rule in azurerm_network_security_group.this.security_rule : rule if rule.name == "PublicApplication" && rule.source_address_prefix == "Internet" && toset(rule.destination_port_ranges) == toset(["80", "443"])]) == 1
    error_message = "Public ingress must be exactly HTTP and HTTPS by default."
  }
  assert {
    condition     = length([for rule in azurerm_network_security_group.this.security_rule : rule if rule.name == "AdministrativeSSH" && toset(rule.source_address_prefixes) == toset(["203.0.113.10/32"])]) == 1
    error_message = "SSH must be limited to supplied admin CIDRs."
  }
}
run "no_admin_cidrs_no_ssh" {
  command = plan
  variables { admin_cidrs = [] }
  assert {
    condition     = length([for rule in azurerm_network_security_group.this.security_rule : rule if rule.name == "AdministrativeSSH"]) == 0
    error_message = "Empty administrative CIDRs must disable SSH ingress."
  }
}
run "reject_worldwide_ssh" {
  command = plan
  variables { admin_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.admin_cidrs]
}
run "reject_public_ssh_port" {
  command = plan
  variables { public_ports = [22, 443] }
  expect_failures = [var.public_ports]
}
