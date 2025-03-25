##########################
# 🔧 USER CONFIGURATION  #
##########################

# Please replace the values below with your own.
# Also check line 101 for security group configuration.

variable "user_config" {
  type = map(string)
  default = {
    api_key        = "ab...cd" # We use this to fetch the details of your Azure Canary image from your Console automatically. This can be a read only API Key.
    console_hash   = "ab...cd"
    location = "US East"
    resource_group_name = "birdy-rg"
    subscription_id = "ab...cd"
    vm_name = "birdy-vm"
    vnet_name = "birdy-vnet"
    vnet_address_space = "10.0.0.0/16"
    subnet_name = "birdy-subnet"
    subnet_prefixes = "10.0.1.0/24"
    nic_name = "birdy-NIC"
    nic_config_name = "birdy-NIC-Config"
    nsg_name = "birdy-NSG"
  }
  description = "Your configuration for the Canary deployment"
}

# Fetch the license details from the Console API with a Read-Only API Key.
data "http" "license" {
  url = "https://${var.user_config.console_hash}.canary.tools/api/v1/license/detailed/info"

  request_headers = {
    "X-Canary-Auth-Token" = var.user_config.api_key
  }
}

# Extracts details of your Canary App.
locals {
  license_info              = jsondecode(data.http.license.response_body)
  azure_app_password        = local.license_info.azurecanary_details.azurecanary_app_password
  azure_app_id              = local.license_info.azurecanary_details.azurecanary_app_id
  azure_app_tenant          = local.license_info.azurecanary_details.azurecanary_thinkst_tenant_id
  azure_app_image_details   = local.license_info.azurecanary_details.azurecanary_image_details
  azure_app_latest_image    = local.azure_app_image_details[length(local.azure_app_image_details) - 1]
  azure_app_latest_image_id = local.azure_app_latest_image.id
  azure_customer_tenant     = local.license_info.azurecanary_details.azurecanary_customer_tenant_id # This will be the default Tenant ID configured on your Console, please override if you are deploying to a different tenant.
}

output "azurecanary_app_details" {
  value = {
    app_id          = local.azure_app_id
    app_password    = local.azure_app_password
    app_tenant      = local.azure_app_tenant
    customer_tenant = local.azure_customer_tenant
  }
}

provider "azurerm" {
  features {}
  subscription_id      = var.user_config.subscription_id
  client_id            = local.azure_app_id
  client_secret        = local.azure_app_password
  tenant_id            = local.azure_customer_tenant
  auxiliary_tenant_ids = [local.azure_app_tenant]
}

# Resource Group
resource "azurerm_resource_group" "birdy" {
  name     = var.user_config.resource_group_name
  location = var.user_config.location
}

# Virtual Network
resource "azurerm_virtual_network" "birdy" {
  name                = var.user_config.vnet_name
  location            = var.user_config.location
  resource_group_name = azurerm_resource_group.birdy.name
  address_space       = [var.user_config.vnet_address_space]
}

# Subnet
resource "azurerm_subnet" "birdy" {
  name                 = var.user_config.subnet_name
  resource_group_name  = azurerm_resource_group.birdy.name
  virtual_network_name = azurerm_virtual_network.birdy.name
  address_prefixes     = [var.user_config.subnet_prefixes]
}

# Network Interface
resource "azurerm_network_interface" "birdy" {
  name                = var.user_config.nic_name
  location            = var.user_config.location
  resource_group_name = azurerm_resource_group.birdy.name

  ip_configuration {
    name                          = var.user_config.nic_config_name
    subnet_id                     = azurerm_subnet.birdy.id
    private_ip_address_allocation = "Dynamic"
  }
}

# If you would like an existing NSG attached to the NIC, please uncomment the following block and replace the values with your own.
#resource "azurerm_network_interface_security_group_association" "birdy" {
#  network_interface_id      = azurerm_network_interface.birdy.id
#  network_security_group_id = "/subscriptions/{subscription_id}/resourceGroups/{resource_group}/providers/Microsoft.Network/networkSecurityGroups/{nsg_name}"
#}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "birdy" {
  name                = var.user_config.vm_name
  resource_group_name = azurerm_resource_group.birdy.name
  location            = var.user_config.location
  size                = "Standard_DS1_v2"
  admin_username      = "unused"
  admin_password      = "ThisIsNotARealPasswordAndWillGoUnused-d9fcdb312f0cb8c593c91a0f7d4a118f"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.birdy.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = local.azure_app_latest_image_id
}