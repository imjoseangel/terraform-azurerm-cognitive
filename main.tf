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

resource "azurerm_app_service" "mainqna" {
  name                = lower(var.application_qna_name)
  resource_group_name = local.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.main.id
  location            = var.location
  app_settings = {
    "AzureSearchAdminKey"        = azurerm_search_service.main.primary_key
    "AzureSearchName"            = azurerm_search_service.main.name
    "DefaultAnswer"              = "No good match found in KB."
    "EnableMultipleTestIndex"    = "true"
    "PrimaryEndpointKey"         = format("%s-PrimaryEndpointKey", lower(var.application_qna_name))
    "QNAMAKER_EXTENSION_VERSION" = "latest"
    "SecondaryEndpointKey"       = format("%s-SecondaryEndpointKey", lower(var.application_qna_name))
    "UserAppInsightsAppId"       = azurerm_application_insights.main.app_id
    "UserAppInsightsKey"         = azurerm_application_insights.main.instrumentation_key
    "UserAppInsightsName"        = azurerm_application_insights.main.name
  }

  client_affinity_enabled = true
  client_cert_enabled     = false
  client_cert_mode        = "Required"
  enabled                 = true
  https_only              = false

  tags = var.tags

  auth_settings {
    additional_login_params        = {}
    allowed_external_redirect_urls = []
    enabled                        = false
    token_refresh_extension_hours  = 0
    token_store_enabled            = false
  }

  identity {
    type = "SystemAssigned"
  }

  logs {
    detailed_error_messages_enabled = false
    failed_request_tracing_enabled  = false

    application_logs {
      file_system_level = "Off"
    }

    http_logs {

      file_system {
        retention_in_days = 1
        retention_in_mb   = 35
      }
    }
  }
}

resource "azurerm_cognitive_account" "main" {
  name                              = lower(var.application_qna_name)
  location                          = "westus"
  resource_group_name               = local.resource_group_name
  kind                              = "QnAMaker"
  local_auth_enabled                = true
  outbound_network_access_restrited = false
  public_network_access_enabled     = true
  qna_runtime_endpoint              = format("https://%s.azurewebsites.net", lower(var.application_qna_name))
  sku_name                          = "S0"
  tags                              = var.tags

  identity {
    type = "SystemAssigned"
  }
}
