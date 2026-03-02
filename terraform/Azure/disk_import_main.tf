# canary.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

variable "resource_group_name" {
  type    = string
  default = "preffered resource group"
}
  
variable "location" {
  type    = string
  default = "eastus"
}

variable "vm_name" {
  type    = string
  default = "preferred VM name"
}

variable "vnet_resource_group_name" {
  type    = string
  default = "target vnet resource group"
}

variable "vnet_name" {
  type    = string
  default = "target vnet name"
}

variable "subnet_name" {
  type    = string
  default = "target subnet name"
}

variable "import_disk" {
  description = "Set to true to import the VHD and create a new snapshot, false to use existing snapshot"
  type        = bool
  default     = true
}
variable "canary_disk_url" {
  description = "SAS URL of the source VHD blob"
  type        = string
  sensitive   = true
  default     = "https://md-ljbkpmrjlxsf.z12.blob.storage.azure.net/mw0xbtcbsm0g/abcd?sv=2018-03-28&sr=b&si=9734e237-c346-4c38-9e41-1a74c339b016&sig=%2FWPiPL69JG3BSW9Q3km5jtHz%2FabT%2FsZATo%2B%2BgdJmbY0%3D"
}

variable "canary_master_image_name" {
  type    = string
  default = "canary-master-image"
}

variable "canary_master_snapshot_name" {
  type    = string
  default = "canary-master-snapshot"
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_subnet" "vm" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

# ------------------------------------------------------------------------------
# Phase 1: Import VHD → Managed Disk → Snapshot (only when import_disk = true)
# ------------------------------------------------------------------------------

resource "azurerm_storage_account" "temp" {
  count = var.import_disk ? 1 : 0

  name                     = "tmpdisk${substr(md5(var.resource_group_name), 0, 12)}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "temp" {
  count = var.import_disk ? 1 : 0

  name               = "vhdimport"
  storage_account_id = azurerm_storage_account.temp[0].id
}

resource "azurerm_storage_blob" "canary_vhd" {
  count = var.import_disk ? 1 : 0

  name                   = "${var.canary_master_image_name}.vhd"
  storage_account_name   = azurerm_storage_account.temp[0].name
  storage_container_name = azurerm_storage_container.temp[0].name
  type                   = "Page"
  source_uri             = var.canary_disk_url
}

resource "azurerm_managed_disk" "canary_master" {
  count = var.import_disk ? 1 : 0

  name                 = var.canary_master_image_name
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Import"
  source_uri           = azurerm_storage_blob.canary_vhd[0].url
  storage_account_id   = azurerm_storage_account.temp[0].id
  os_type              = "Linux"
}

resource "azurerm_snapshot" "canary_master" {
  count = var.import_disk ? 1 : 0

  name                = var.canary_master_snapshot_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  create_option       = "Copy"
  source_uri          = azurerm_managed_disk.canary_master[0].id
}

# ------------------------------------------------------------------------------
# Phase 1 Alt: Reference existing snapshot (when import_disk = false)
# ------------------------------------------------------------------------------

data "azurerm_snapshot" "existing" {
  count = var.import_disk ? 0 : 1

  name                = var.canary_master_snapshot_name
  resource_group_name = data.azurerm_resource_group.main.name
}

locals {
  snapshot_id = var.import_disk ? azurerm_snapshot.canary_master[0].id : data.azurerm_snapshot.existing[0].id
}

# ------------------------------------------------------------------------------
# Phase 2: Create VM from snapshot
# ------------------------------------------------------------------------------

resource "azurerm_managed_disk" "vm_osdisk" {
  name                 = "${var.vm_name}-osdisk"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Copy"
  source_resource_id   = local.snapshot_id
  os_type              = "Linux"
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.vm_name}-nic"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  vm_size             = var.vm_size

  network_interface_ids = [azurerm_network_interface.vm.id]

  storage_os_disk {
    name            = azurerm_managed_disk.vm_osdisk.name
    managed_disk_id = azurerm_managed_disk.vm_osdisk.id
    create_option   = "Attach"
    os_type         = "Linux"
  }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

output "snapshot_id" {
  value = local.snapshot_id
}

output "vm_id" {
  value = azurerm_virtual_machine.vm.id
}

output "private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}