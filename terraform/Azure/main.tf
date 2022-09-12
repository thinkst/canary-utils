# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.21.1"
    }
  }

  required_version = ">= 1.1.0"
}

# Authenticate to Azure as Canary app. Below specifies what fields are needed. 
# Consider safer authentication methods for production use as documented by Hashicorp: 
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret
provider "azurerm" {
  features {}
  
  subscription_id = "<YOUR SUBSCRIPTION ID>"
  client_id       = "<YOUR CANARY APP SERVICE ACCOUNT USERNAME>"
  client_secret   = "<YOUR CANARY APP SERVICE ACCOUNT PASSWORD>"
  tenant_id       = "YOUR TENANT ID"
  auxiliary_tenant_ids = ["TENANT ID OF CANARY APP SERVICE ACCOUNT"]
}

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = "<DESTINATION RESOURCE GROUP>"
  location = "<DESTINATION REGION>"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
  name                = "mybird_nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "mybirdip"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "main" {
  name                = "mybird"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vm_size               = "Standard_B1ls"
  network_interface_ids = [azurerm_network_interface.main.id]
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = "/subscriptions/<AZURE IMAGE GALLERY LOCATION>/images/AzureCanary-3.6.2-0f374ec"
  }

  storage_os_disk {
    name              = "mybird_os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "mybird"
    admin_username = "notused"
    admin_password = "Password123"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
