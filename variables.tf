variable "resource_group" {
  description = "The name of the resource group in which to create the Azure resources"
  default = ""
}

variable "location" {
  description = "The location/region where the session hosts are created"
  default = ""
}

variable "virtual_network_name" {
  description = "Virtual Network Name"
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

variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  default = ""
}

variable "custom_image_location" {
  description = "The Azure Region in which the resources in this example should exist"
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

variable "vm_name" {
  description = "Virtual Machine Name (prefix)"
  default = ""
}

variable "vm_count" {
  description = "Number of Session Host VMs to create" 
  default = "1"
}

variable "domain" {
  description = "Domain to join" 
  default = ""
}

variable "domainuser" {
  description = "Domain Join User Name" 
  default = ""
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
  default = ""
}  

variable "hostpoolname" {
  description = "Host Pool Name to Register Session Hosts" 
  default = ""
  }

variable "artifactslocation" {
  description = "Location of WVD Artifacts (Don't Change)" 
  default = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip"
}
