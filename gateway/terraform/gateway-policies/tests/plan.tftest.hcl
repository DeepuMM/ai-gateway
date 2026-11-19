# Plan test with mocked providers: every file in gateway/policy-fragments/ becomes an APIM policy fragment, and every
# fragment a policy template includes has a file. No Azure access. Fixture platform coordinates (in the pipeline: the
# GitHub environment's variables).
variables {
  environment                   = "dev"
  tenant_id                     = "fcf67057-50c9-4ad4-98f3-ffca64add9e9"
  agents_app_id                 = "11111111-2222-3333-4444-555555555555"
  apim_subscription_id          = "00000000-0000-0000-0000-000000000000"
  apim_resource_group           = "rg"
  apim_name                     = "apim"
  content_safety_account        = "cs-sbx-bbf0o"
  content_safety_resource_group = "rg-ai-gateway-sandbox"
}

mock_provider "azapi" {}

mock_provider "azurerm" {
  mock_data "azurerm_api_management" {
    defaults = {
      id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ApiManagement/service/apim"
      name        = "apim"
      gateway_url = "https://apim.azure-api.net"
    }
  }
  mock_data "azurerm_cognitive_account" {
    defaults = {
      kind     = "ContentSafety"
      name     = "cs-sbx-bbf0o"
      endpoint = "https://cs-sbx-bbf0o.cognitiveservices.azure.com/"
    }
  }
}

run "deploys_shared_policy_fragments" {
  command = plan

  assert {
    condition = alltrue([for id in ["agent-guardrails", "agent-caller", "agent-route", "project-inbound", "project-outbound", "model-api-caller", "model-api-route", "model-content-safety", "tool-caller", "tool-route"] :
    contains(keys(azurerm_api_management_policy_fragment.shared), id)])
    error_message = "Every fragment the policy templates include should be deployed."
  }
  assert {
    condition     = alltrue([for f in azurerm_api_management_policy_fragment.shared : f.format == "rawxml"])
    error_message = "Fragments are stored as raw XML (no re-serialisation drift)."
  }
  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["agent-guardrails"].value, "AI_ROUTE_SUSPENDED")
    error_message = "agent-guardrails should carry the kill switch."
  }
  assert {
    condition     = azurerm_api_management_named_value.tenant_id.value == "fcf67057-50c9-4ad4-98f3-ffca64add9e9"
    error_message = "gateway-tenant-id should be the environment's tenant (AZURE_TENANT_ID)."
  }
  assert {
    condition     = azurerm_api_management_named_value.kill_switch_all.name == "ks-gateway-all" && azurerm_api_management_named_value.kill_switch_all.value == "active"
    error_message = "The global kill switch ks-gateway-all starts active."
  }
  assert {
    condition = alltrue([for id in ["agent-guardrails", "model-api-route"] :
    strcontains(azurerm_api_management_policy_fragment.shared[id].value, "{{ks-gateway-all}}")])
    error_message = "agent-guardrails and model-api-route should check the global kill switch."
  }
  assert {
    condition     = azapi_resource.content_safety_backend.name == "content-safety" && azapi_resource.content_safety_backend.body.properties.url == "https://cs-sbx-bbf0o.cognitiveservices.azure.com/"
    error_message = "The content-safety backend should point at the environment's Content Safety account."
  }
  assert {
    condition     = azapi_resource.content_safety_backend.body.properties.credentials.managedIdentity.resource == "https://cognitiveservices.azure.com"
    error_message = "APIM should call Content Safety with its managed identity (no keys)."
  }
  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["model-content-safety"].value, "backend-id=\"content-safety\"")
    error_message = "model-content-safety should use the content-safety backend."
  }
  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["model-content-safety"].value, "enforce-on-completions=\"@(context.Variables.GetValueOrDefault&lt;bool&gt;(&quot;cs-check-answers&quot;, false))\"")
    error_message = "Answer checks are opt-in per project or model (cs-check-answers), off by default."
  }
  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["model-content-safety"].value, "cs-violence&quot;, 4)")
    error_message = "model-content-safety should read each project's setting and default to 4."
  }

  assert {
    condition = alltrue([for s in ["AGENT_PATH_NOT_ALLOWED", "x-ms-user-identity", "version_indicator", "agent_reference", "StartsWith(&quot;endpoint/&quot;)"] :
    strcontains(azurerm_api_management_policy_fragment.shared["agent-route"].value, s)])
    error_message = "agent-route should pass through only the agent's own endpoints, pin the evaluated version (body or session) and send the caller's identity."
  }

  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["model-api-route"].value, "<llm-emit-token-metric") && strcontains(azurerm_api_management_policy_fragment.shared["agent-route"].value, "<llm-emit-token-metric")
    error_message = "Token metrics should be emitted on both hops (model-api-route, agent-route)."
  }

  assert {
    condition = alltrue([for x in ["<validate-jwt", "<audience>{{agents-app-id}}</audience>", "<audience>https://ai.azure.com</audience>", "access-gateway", "access-foundry", "agents.all", "AGENT_NOT_ALLOWED", "x-foundry-authorization", "CALLER_MISMATCH", "foundry-token", "<set-header name=\"x-ms-user-identity\" exists-action=\"delete\" />"] :
    strcontains(azurerm_api_management_policy_fragment.shared["agent-caller"].value, x)])
    error_message = "agent-caller should require every check in the agent's access list: agent app token with the role (gateway), the caller's Foundry token (foundry), both of the same caller; and drop caller-supplied identity headers."
  }
  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["project-inbound"].value, "foundry-token") && strcontains(azurerm_api_management_policy_fragment.shared["project-inbound"].value, "<authentication-managed-identity resource=\"https://ai.azure.com\" />")
    error_message = "project-inbound should send the caller's Foundry token when agent-caller forwards one, else APIM's managed identity."
  }
  assert {
    condition     = azurerm_api_management_named_value.agents_app_id.name == "agents-app-id" && azurerm_api_management_named_value.agents_app_id.value == "11111111-2222-3333-4444-555555555555"
    error_message = "agents-app-id should be the environment's agent app (AGENTS_APP_ID)."
  }
  assert {
    condition = alltrue([for id in ["agent-guardrails", "project-inbound"] :
    strcontains(azurerm_api_management_policy_fragment.shared[id].value, "caller-oid") && !strcontains(azurerm_api_management_policy_fragment.shared[id].value, "context.Subscription")])
    error_message = "Agent limits should count per caller (token object ID), not per subscription key."
  }


  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["model-content-safety"].value, "LastOrDefault(m => (string)m[\"role\"] == \"user\")") && strcontains(azurerm_api_management_policy_fragment.shared["model-content-safety"].value, "<set-body>@((string)context.Variables[\"cs-original-body\"])</set-body>")
    error_message = "model-content-safety should check only the latest user message and restore the full request for the model."
  }

  assert {
    condition     = strcontains(azurerm_api_management_policy_fragment.shared["tool-caller"].value, "<audience>https://cognitiveservices.azure.com</audience>") && strcontains(azurerm_api_management_policy_fragment.shared["tool-caller"].value, "tool-callers") && strcontains(azurerm_api_management_policy_fragment.shared["tool-caller"].value, "<set-header name=\"Authorization\" exists-action=\"delete\" />")
    error_message = "tool-caller should accept only the projects the tool is shared with and never pass their token to the tool."
  }

  assert {
    condition = alltrue([for s in ["{{ks-gateway-all}}", "tool-status", "<rate-limit-by-key", "tools/call", "TOOL_NOT_ALLOWED"] :
    strcontains(azurerm_api_management_policy_fragment.shared["tool-route"].value, s)])
    error_message = "tool-route should check both kill switches, limit calls and refuse tools the owner didn't expose."
  }
}

run "requires_a_content_safety_account" {
  command = plan

  override_data {
    target = data.azurerm_cognitive_account.content_safety
    values = {
      kind     = "AIServices" # gateway.content_safety names an account that is not Content Safety
      endpoint = "https://other.cognitiveservices.azure.com/"
    }
  }

  expect_failures = [data.azurerm_cognitive_account.content_safety]
}

run "gateway_telemetry_when_configured" {
  command = plan

  variables {
    app_insights_name           = "aiazrgtstmodelnpr013471ad" # APP_INSIGHTS_NAME set: telemetry configured
    app_insights_resource_group = "az-rg-tst-model-npr-01"
  }

  override_data {
    target = data.azurerm_cognitive_account.content_safety
    values = { kind = "ContentSafety", endpoint = "https://cs-tst-3471ad.cognitiveservices.azure.com/" }
  }

  override_data {
    target = data.azurerm_application_insights.gateway[0]
    values = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Insights/components/appi"
      connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = length(azurerm_api_management_logger.app_insights) == 1 && azapi_resource.diagnostic[0].body.properties.metrics == true && azapi_resource.diagnostic[0].body.properties.httpCorrelationProtocol == "W3C"
    error_message = "With gateway.app_insights, the gateway should log to Application Insights with custom metrics and W3C correlation."
  }

  assert {
    condition     = azapi_resource.diagnostic[0].body.properties.frontend.request.body.bytes == 0 && azapi_resource.diagnostic[0].body.properties.backend.response.body.bytes == 0
    error_message = "Gateway telemetry must not log prompts or answers (bodies)."
  }
}
