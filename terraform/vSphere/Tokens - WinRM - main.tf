provider "vsphere" {
  user           = "<YOURVSPHERE USERNAME@vsphere.local>"
  password       = "<YOUR VSPHERE PASSWORD>"
  vsphere_server = "<YOUR VSPHERE HOSTNAME OR IP>"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "<YOUR VSPHERE DC>"
}

data "vsphere_datastore" "datastore" {
  name          = "<YOUR VSPHERE DATASTORENAME>"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "<YOUR VSPHERE RESOURCE POOL NAME>"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
  name          = "<YOUR ESXI HOST IP OR HOSTNAME>"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "<YOUR VSPHERE NETWORK NAME>"
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vmFromLocalOvf" {
  name                       = "Terraform_Canary"
  resource_pool_id           = data.vsphere_resource_pool.pool.id
  datastore_id               = data.vsphere_datastore.datastore.id
  host_system_id             = data.vsphere_host.host.id
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0
  datacenter_id              = data.vsphere_datacenter.dc.id
  ovf_deploy {
    local_ovf_path = "/Users/gareth/Downloads/VirtualCanary_0f374ec1.ova"
  }
  # winrm connection values 
  connection {
    type     = "winrm"
    host     = "<endpoint_to_be_tokened_IP>"
    user     = "<endpoint_username>"
    password = "<endpoint_password>"
    timeout  = "5m"
  }

  # copies file from local directory to remote directory
  provisioner "file" {
    source      = "<script_location_on_terraform_host>"
    destination = "<destination_location_on_endpoint>"
  }

  # executes the following commands remotely https://www.terraform.io/language/resources/provisioners/remote-exec
  provisioner "remote-exec" {
    inline = [
      "<destination_script_location>",
      "del <destination_script_location>",
    ]
  }
}