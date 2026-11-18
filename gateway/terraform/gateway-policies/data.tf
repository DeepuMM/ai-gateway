# The APIM instance and the Content Safety account are owned by other stacks (gateway/sandbox, or the platform's
# own infrastructure): looked up, never changed.
data "azurerm_api_management" "this" {
  name                = local.env.gateway.apim_name
  resource_group_name = local.env.gateway.resource_group
}

# Azure AI Content Safety account for the model-content-safety fragment (environment file gateway.content_safety).
# Its owner grants the APIM managed identity "Cognitive Services User" on it.
data "azurerm_cognitive_account" "content_safety" {
  name                = local.content_safety.account_name
  resource_group_name = local.content_safety.resource_group

  lifecycle {
    precondition {
      condition     = local.content_safety_set
      error_message = "Environment ${var.environment} needs the Azure AI Content Safety account the gateway checks prompts with: GitHub variables CONTENT_SAFETY_ACCOUNT and CONTENT_SAFETY_RESOURCE_GROUP."
    }
    postcondition {
      condition     = self.kind == "ContentSafety"
      error_message = "CONTENT_SAFETY_ACCOUNT must be an Azure AI Content Safety account (kind ContentSafety)."
    }
  }
}
