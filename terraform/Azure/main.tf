# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  
  subscription_id = "<YOUR SUBSCRIPTION ID>"
  client_id       = "<YOUR CANARY APP SERVICE ACCOUNT USERNAME>"
  client_secret   = "<YOUR CANARY APP SERVICE ACCOUNT PASSWORD>"
  tenant_id       = "YOUR TENANT ID"
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
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.main.id]
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = "/subscriptions/<AZURE IMAGE GALLARY LOCATION>/images/AzureCanary-3.6.0-0e3d6b0"
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