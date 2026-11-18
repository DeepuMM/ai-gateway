## Gateway telemetry (environment file gateway.app_insights, optional): an Application Insights logger and the
## gateway-wide diagnostic. Custom metrics are on, for the token metrics the fragments emit (llm-emit-token-metric:
## model-api-route per project and model, agent-route per project, agent and consumer). W3C correlation, so a
## caller's traceparent continues through the gateway into Foundry and the agent. Request metadata only: no headers
## and no bodies (prompts and answers are not logged here).

data "azurerm_application_insights" "gateway" {
  count               = local.app_insights_set ? 1 : 0
  name                = local.env.gateway.app_insights.name
  resource_group_name = local.env.gateway.app_insights.resource_group
}

resource "azurerm_api_management_logger" "app_insights" {
  count               = local.app_insights_set ? 1 : 0
  name                = "app-insights"
  api_management_name = data.azurerm_api_management.this.name
  resource_group_name = data.azurerm_api_management.this.resource_group_name
  resource_id         = data.azurerm_application_insights.gateway[0].id
  description         = "Gateway telemetry and token metrics (gateway-policy-deployment)"

  application_insights {
    connection_string = data.azurerm_application_insights.gateway[0].connection_string
  }
}

# azurerm's diagnostic resource has no `metrics` switch (custom metrics with dimensions): azapi.
resource "azapi_resource" "diagnostic" {
  count     = local.app_insights_set ? 1 : 0
  type      = "Microsoft.ApiManagement/service/diagnostics@2024-05-01"
  name      = "applicationinsights"
  parent_id = data.azurerm_api_management.this.id
  body = {
    properties = {
      loggerId                = azurerm_api_management_logger.app_insights[0].id
      alwaysLog               = "allErrors"
      httpCorrelationProtocol = "W3C"
      verbosity               = "information"
      logClientIp             = false
      metrics                 = true
      sampling                = { samplingType = "fixed", percentage = 100 }
      frontend = {
        request  = { headers = [], body = { bytes = 0 } }
        response = { headers = [], body = { bytes = 0 } }
      }
      backend = {
        request  = { headers = [], body = { bytes = 0 } }
        response = { headers = [], body = { bytes = 0 } }
      }
    }
  }
}
