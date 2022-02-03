variable "name" {
  description = "Name of Azure Postgres service."
}

variable "create_resource_group" {
  description = "Whether to create resource group"
  default     = true
}

variable "resource_group_name" {
  description = "A container that holds related resources for an Azure solution"
  default     = "rg-demo-westeurope-01"
}

variable "location" {
  description = "The location/region to keep all resources. To get the list of all locations with table format from azure cli, run 'az account list-locations -o table'"
  default     = "westeurope"
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default     = {}
}
