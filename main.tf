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
  name                = format("%s-search", lower(var.name))
  resource_group_name = local.resource_group_name
  location            = local.location
  sku                 = var.search_sku
  partition_count     = var.search_sku == "standard" ? var.partition_count : null
  replica_count       = var.search_sku == "standard" ? var.replica_count : null
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                                  = lower(var.name)
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
  name                         = lower(var.name)
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
  name                = format("%s-qna", lower(var.name))
  resource_group_name = local.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.main.id
  location            = var.location
  app_settings = {
    "AzureSearchAdminKey"        = azurerm_search_service.main.primary_key
    "AzureSearchName"            = azurerm_search_service.main.name
    "DefaultAnswer"              = "No good match found in KB."
    "EnableMultipleTestIndex"    = "true"
    "PrimaryEndpointKey"         = format("%s-qna-PrimaryEndpointKey", lower(var.name))
    "QNAMAKER_EXTENSION_VERSION" = "latest"
    "SecondaryEndpointKey"       = format("%s-qna-SecondaryEndpointKey", lower(var.name))
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
  name                              = format("%s-qna", lower(var.name))
  location                          = "westus"
  resource_group_name               = local.resource_group_name
  kind                              = "QnAMaker"
  local_auth_enabled                = true
  outbound_network_access_restrited = false
  public_network_access_enabled     = true
  qna_runtime_endpoint              = format("https://%s-qna.azurewebsites.net", lower(var.name))
  sku_name                          = "S0"
  tags                              = var.tags

  identity {
    type = "SystemAssigned"
  }
}

module "serviceprincipal" {
  source  = "imjoseangel/serviceprincipal/azurerm"
  name    = lower(var.name)
  version = "22.1.12"
}

resource "azurerm_app_service" "main" {
  name                = lower(var.name)
  resource_group_name = local.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.main.id
  location            = var.location
  app_settings = {
    "MicrosoftAppId"               = module.serviceprincipal.client_id
    "MicrosoftAppPassword"         = module.serviceprincipal.client_secret
    "WEBSITE_NODE_DEFAULT_VERSION" = "10.14.1"
  }
  client_affinity_enabled = true
  client_cert_enabled     = false
  client_cert_mode        = "Required"
  enabled                 = true
  https_only              = false

  tags = var.tags

  auth_settings {
    enabled                       = false
    token_refresh_extension_hours = 0
    token_store_enabled           = false
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

  site_config {
    acr_use_managed_identity_credentials = false
    always_on                            = false
    default_documents = [
      "Default.htm",
      "Default.html",
      "Default.asp",
      "index.htm",
      "index.html",
      "iisstart.htm",
      "default.aspx",
      "index.php",
      "hostingstart.html",
    ]
    dotnet_framework_version    = "v4.0"
    ftps_state                  = "AllAllowed"
    http2_enabled               = false
    ip_restriction              = []
    local_mysql_enabled         = false
    managed_pipeline_mode       = "Integrated"
    min_tls_version             = "1.2"
    number_of_workers           = 1
    remote_debugging_enabled    = false
    remote_debugging_version    = "VS2019"
    scm_ip_restriction          = []
    scm_type                    = "None"
    scm_use_main_ip_restriction = false
    use_32_bit_worker_process   = true
    vnet_route_all_enabled      = true
    websockets_enabled          = true

    cors {
      allowed_origins = [
        "https://botservice.hosting.portal.azure.net",
        "https://hosting.onecloud.azure-test.net/",
      ]
      support_credentials = false
    }
  }
}

resource "azurerm_cognitive_account" "mainluis" {
  name                              = format("%s-luis", lower(var.name))
  location                          = "westeurope"
  resource_group_name               = local.resource_group_name
  kind                              = "LUIS"
  local_auth_enabled                = true
  outbound_network_access_restrited = false
  public_network_access_enabled     = true
  sku_name                          = "S0"
  tags                              = var.tags
}

resource "azurerm_cognitive_account" "mainluisauth" {
  name                              = format("%s-luis-authoring", lower(var.name))
  location                          = "westeurope"
  resource_group_name               = local.resource_group_name
  kind                              = "LUIS.Authoring"
  local_auth_enabled                = true
  outbound_network_access_restrited = false
  public_network_access_enabled     = true
  sku_name                          = "F0"
  tags                              = var.tags
}

resource "azurerm_bot_service_azure_bot" "main" {
  name                                  = lower(var.name)
  resource_group_name                   = local.resource_group_name
  location                              = "global"
  display_name                          = lower(var.name)
  endpoint                              = format("https://%s.azurewebsites.net/api/messages", lower(var.name))
  developer_app_insights_application_id = azurerm_application_insights.main.app_id
  developer_app_insights_key            = azurerm_application_insights.main.instrumentation_key
  microsoft_app_id                      = module.serviceprincipal.client_id
  sku                                   = "S1"
  tags                                  = var.tags
}
