variable "search_name" {
  description = "Name of Azure Search service."
  type        = string
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

variable "search_sku" {
  description = "(Required) The SKU which should be used for this Search Service. Possible values are basic, free, standard, standard2, standard3, storage_optimized_l1 and storage_optimized_l2. Changing this forces a new Search Service to be created."
  default     = "standard"
  type        = string
}

variable "partition_count" {
  description = "(Optional) The number of partitions which should be created."
  default     = 1
  type        = number
}

variable "replica_count" {
  description = "(Optional) The number of replica's which should be created."
  default     = 1
  type        = number
}


variable "search_name" {
  description = "Name of Azure Search service."
  type        = string
}
variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default     = {}
}
