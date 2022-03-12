#-------------------------------
# Local Declarations
#-------------------------------
locals {
  resource_group_name = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
  location            = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
}

data "azurerm_client_config" "current" {}

#---------------------------------------------------------
# Resource Group Creation or selection - Default is "true"
#---------------------------------------------------------
data "azurerm_resource_group" "rgrp" {
  count = var.create_resource_group == false ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "rg" {
  #ts:skip=AC_AZURE_0389 RSG lock should be skipped for now.
  count    = var.create_resource_group ? 1 : 0
  name     = lower(var.resource_group_name)
  location = var.location
  tags     = merge({ "ResourceName" = format("%s", var.resource_group_name) }, var.tags, )
}

resource "azurerm_search_service" "main" {
  name                = (lower(var.search_name))
  resource_group_name = local.resource_group_name
  location            = local.location
  sku                 = var.search_sku
  partition_count     = var.search_sku == "standard" ? var.partition_count : null
  replica_count       = var.search_sku == "standard" ? var.replica_count : null
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                                  = lower(var.application_insights_name)
  resource_group_name                   = local.resource_group_name
  location                              = local.location
  application_type                      = "web"
  daily_data_cap_in_gb                  = 100
  daily_data_cap_notifications_disabled = false
  disable_ip_masking                    = false
  internet_ingestion_enabled            = true
  internet_query_enabled                = true
  local_authentication_disabled         = false
  retention_in_days                     = 90
  sampling_percentage                   = 0
  tags                                  = var.tags
}

resource "azurerm_app_service_plan" "main" {
  name                         = lower(var.application_plan_name)
  location                     = var.location
  resource_group_name          = local.resource_group_name
  is_xenon                     = false
  kind                         = "app"
  maximum_elastic_worker_count = 1
  per_site_scaling             = false
  reserved                     = false
  tags                         = var.tags
  zone_redundant               = false

  sku {
    capacity = 1
    size     = "P1v3"
    tier     = "PremiumV2"
  }

}
