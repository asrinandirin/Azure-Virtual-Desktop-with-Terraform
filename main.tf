terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subnet" "subnet" {
  name                 = "${var.virtual_network_subnet}"
  virtual_network_name = "${var.virtual_network_name}"
  resource_group_name  = "${var.virtual_network_subnet_rg}"
}

data "azurerm_image" "custom" {
  name                = "${var.custom_image_name}"
  resource_group_name = "${var.custom_image_resource_group_name}"
}

data "azurerm_network_security_group" "security_group" {
  name                = "${var.network_security_group}"
  resource_group_name = "${var.resource_group}"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}${count.index + 1}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group}"
  count               = "${var.vm_count}"

  ip_configuration {
    name                                    = "webipconfig${count.index}"
    subnet_id                               = "${data.azurerm_subnet.subnet.id}"
    private_ip_address_allocation           = "Dynamic"
    }
}

resource "azurerm_network_interface_security_group_association" "security_group_association" {
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = "${data.azurerm_network_security_group.security_group.id}"
  count                     = "${var.vm_count}"

}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.vm_name}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = "${var.vm_count}"

  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.custom.id}"
  }


  storage_os_disk {
    name          = "${var.vm_name}${count.index + 1}"
    create_option = "FromImage"
  }


  os_profile {
    computer_name  = "${var.vm_name}${count.index + 1}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }
}

resource "azurerm_virtual_machine_extension" "domainjoinext" {
  name                 = "join-domain"
  virtual_machine_id   = element(azurerm_virtual_machine.vm.*.id, count.index)
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  depends_on           = ["azurerm_virtual_machine.vm"]
  count                = "${var.vm_count}"

  settings = <<SETTINGS
    {
        "Name": "${var.domain}",
        "OUPath": "${var.oupath}",
        "User": "${var.domainuser}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "Password": "${var.domainpassword}"
    }
PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "registersessionhost" {
  name                 = "registersessionhost"
  virtual_machine_id   = element(azurerm_virtual_machine.vm.*.id, count.index)
  publisher            = "Microsoft.Powershell"
  depends_on           = ["azurerm_virtual_machine_extension.domainjoinext"]
  count                = "${var.vm_count}"
  type = "DSC"
  type_handler_version = "2.73"
  auto_upgrade_minor_version = true
  settings = <<SETTINGS
    {
        "ModulesUrl": "${var.artifactslocation}",
        "ConfigurationFunction" : "Configuration.ps1\\AddSessionHost",
        "Properties": {
            "hostPoolName": "${var.hostpoolname}",
            "registrationInfoToken": "${var.regtoken}"
        }
    }
SETTINGS
}