# Deploy Azure Virtual Desktop Instances with Terraform

### This article teaches you how to use Terraform to:

- Create fully controlled Azure Virtual Desktop instances with custom configurations.
- Join your Azure Virtual Desktop to your custom domain.
- Register Azure Virtual Desktop instances to a session host.

By the end of this article, you will be able to create custom-configured Azure Virtual Desktop instances with just three simple Terraform commands.

**I assume you already know Terraform and have it installed in your environment.**

---

### Module Usage

```yaml
module "vdi-module" {

      source= "github.com/asrinandirin/Azure-Virtual-Desktop-with-Terraform"
      
      resource_group             = ""         // Resource group in which to create the Azure resources.
      location                   = ""         // The location/region where the session hosts are created.
      virtual_network_name       = ""         // Virtual Network Name that subnet live.
      virtual_network_subnet     = ""         // Subnet name VM's will be deployed.
      virtual_network_subnet_rg  = ""         // The resource group where the subnet live.
      network_security_group     = ""         // Network Security Group name that NIC will be bounded.
      vm_size                    = ""         // Specifies the size of the virtual machine.   
      custom_image_location      = ""         // Custom image location
      custom_image_resource_group_name = ""   // Resource Group in which the Custom Image exists     
      custom_image_name          = ""         // Custom image name
      admin_username             = ""         // Local Admin Username
      admin_password             = ""         // Admin Password
      vm_name                    = ""         // Virtual Machine Name (prefix)
      vm_count                   = ""         // Number of Session Host VMs to create
      domain                     = ""         // Domain to join
      domainuser                 = ""         // Domain Join User Name
      domainpassword             = ""         // Domain user password
      oupath                     = ""         // OU Path
      regtoken                   = ""         // Host Pool Registration Token
      hostpoolname               = ""         // Host Pool Name to Register Session Hosts

    }
```
# Module Explanations

### Let's start by examining our [main.tf](http://main.tf/) file first.

So this code below sets up all the necessary providers for your Terraform config. Specifically, we're talking about the **`azurerm`** and **`azuread`** providers. Plus, we've gone ahead and configured that **`azurerm`** provider without any extra features.

```yaml
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
```

**So, when you're in the real world**, you should have a bunch of stuff set up already for your deployment. Like, you made some custom images, you have a virtual network and some subnets, and each one needs a network security group of its own. (We are not going to create each in this article, our focus is more like deploying Azure Virtual Desktops in an **existing environment**)

That’s why we will use data blocks to retrieve information about these resources. The `data` block helps Terraform be more flexible and powerful, allowing you to retrieve and use external data in your configuration.

These **`data`** blocks retrieve information about Azure resources such as subnets, custom images, and network security groups. We will use the retrieved information in the Terraform configuration to make decisions, configure resources, or reference specific Azure resources during infrastructure provisioning and management.

```yaml
data "azurerm_subnet" "subnet" {
  name                 = "${var.virtual_network_subnet}"
  virtual_network_name = "${var.virtual_network_name}"
  resource_group_name  = "${var.virtual_network_subnet_rg}"
}

data "azurerm_image" "custom_image" {
  name                = "${var.custom_image_name}"
  resource_group_name = "${var.custom_image_resource_group_name}"
}

data "azurerm_network_security_group" "security_group" {
  name                = "${var.network_security_group}"
  resource_group_name = "${var.resource_group}"
}
```

We will create a Network Interface Card (NIC) in a desired subnet, assign it to a pre-configured network security group, and then connect it to the Azure Virtual Desktop instance.

Let’s create our NIC with the code below.

```yaml
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
```

If you are confused about the definition of "count" in the code above,

The Terraform language defines `count` as a meta-argument that can be used with modules and all resource types.

You can pass a whole number to the `count` meta-argument, which creates as many instances of the resource or module as specified. Each instance has a distinct infrastructure object associated with it and is separately created, updated, or destroyed when the configuration is applied.

If you are still confused or It stil seems complicated, **we use “count” for the answer of how many instance you want to create.** 

**And count.index gives you a number in order. (0,1,2,3,4 …) (First count.index is always zero).** 

So if you give “count” 5 for above code, there will be 5 NIC created with names of  (<Your vm name> <Count index + 1>). 

And the next, we will bound all NIC’s with spesific Network Security Group. 

```yaml
resource "azurerm_network_interface_security_group_association" "security_group_association" {
  network_interface_id      = azurerm_network_interface.nic[{count.index}].id
  network_security_group_id = "${data.azurerm_network_security_group.security_group.id}"
	count = "{var.vm_count}"
}
```

This resource block creates an association between a network interface and a network security group for a specified number of virtual machines.

Based on your specific configuration, you can add multiple specifications by referring to the official Azurerm documentation. However, the following worked well. 

```yaml
resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.vm_name}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = "${var.vm_count}"

  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.custom_image.id}"
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
```

**This is the part we say we will use our custom private image.** 

```yaml
  storage_image_reference {
    id = "${data.azurerm_image.custom_image.id}"
  }

  storage_os_disk {
    name          = "${var.vm_name}${count.index + 1}"
    create_option = "FromImage"
  }
```

So far, we have created Azure Virtual Desktop instances and placed them in a specific subnet with a specific Network Security Group.
Next, we will join them to our domain and finally register them with the desired host pool.

**The code below is working well for joining the domain. We will discuss all variables shortly.**

```yaml
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
```

**And finally the code below working well for registering the host pool.** 

```yaml
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
```

### **We have completed the main part of our structure. We now need to define the necessary variables to make main.tf functional.**

---

**Be careful which resources in which resource groups for your configuration. It can be a problem when you try “terraform plan” command.** 

Let’s start with general variables

```yaml
variable "resource_group" {
  description = "The name of the resource group in which to create the Azure Virtual Desktop"
  default = "" // Example resource group like "my-rg"
}

variable "location" {
  description = "The location/region where the session hosts are created"
  default = "" //westeurope, eastus
}
```

Network Variables 

```yaml
variable "virtual_network_name" {
  description = "Virtual network name that subnet live."
  default = ""
}

variable "virtual_network_subnet" {
  description = "Subnet name VM's will be deployed."
  default = ""
}

variable "virtual_network_subnet_rg" {
  description = "The resource group where the subnet live."
  default = ""
}

variable "network_security_group" {
  description = "Network Security Group name that NIC will be bounded."
  default = ""
}

```

Virtual Desktop Machine Variables

```yaml
variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  default = "" // -> "Standard_D4hs_v3 or etc"
}

variable "custom_image_location" {
  description = "The location in which the private custom images live"
  type = string
  default = "" 
}

variable "custom_image_resource_group_name" {
  description = "The name of the Resource Group in which the Custom Image exists."
  type = string
  default = ""
}

variable "custom_image_name" {
  description = "The name of the Custom Image to provision this Virtual Machine from."
  type = string
  default = ""
}

variable "admin_username" {
  description = "Local Admin Username"
  default = ""
}

variable "admin_password" {
  description = "Admin Password"
  default = ""
}

// To figure out what names will be given to your instances, check out resource config. "${var.vm_name}${count.index + 1}" 
// For this example, if you give count 3 you will have 3 VM instances that named like (vm-host**-1**, vm-host**-2**, vm-host**-3**)
variable "vm_name" {
  description = "Virtual Machine Name (prefix)"
  default = "vm-host-"
}

variable "vm_count" {
  description = "Number of Session Host VMs to create" 
  default = "1"
}

```

 

Domain and registration variables are below

```yaml
variable "domain" {
  description = "Domain to join" 
  default = "" 
}

// Give user credentials that have permissions on your domain environment.
variable "domainuser" {
  description = "Domain Join User Name" 
  default = "asrin.andirin@d-teknoloji.com.tr"
}

variable "oupath" {
  description = "OU Path"
  default = ""
}

variable "domainpassword" {
  description = "Domain User Password" 
  default = ""
}

variable "regtoken" {
  description = "Host Pool Registration Token" 
	default = "Your token here"
}
  

variable "hostpoolname" {
  description = "Host Pool Name to Register Session Hosts" 
  default = ""
  }

// Dont need to change below. 
variable "artifactslocation" {
  description = "Location of WVD Artifacts (Don't Change)" 
  default = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip"
}
```

To summarize, once all variables are filled, you must initialize, plan, and apply your Terraform configurations. 

At the end you will have an output like,

and you will have 5 resources per count.