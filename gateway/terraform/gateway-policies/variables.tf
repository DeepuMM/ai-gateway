variable "environment" {
  description = "Environment name (dev, uat, prd)."
  type        = string
  default     = "dev"
}

# Platform coordinates of the environment: GitHub environment variables (model-<environment>), passed by the workflow
# as TF_VAR_*. Nothing about an environment is kept in this repository.
variable "tenant_id" {
  description = "The environment's Entra tenant. GitHub variable AZURE_TENANT_ID."
  type        = string
}

variable "agents_app_id" {
  description = "Client ID of the gateway's agent app (Entra; scripts/setup_agents_app.py): the audience of agent callers' tokens. GitHub variable AGENTS_APP_ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.agents_app_id))
    error_message = "agents_app_id must be the agent app's client ID (a GUID): GitHub variable AGENTS_APP_ID, from scripts/setup_agents_app.py."
  }
}

variable "apim_subscription_id" {
  description = "Subscription of the AI gateway (APIM). GitHub variable APIM_SUBSCRIPTION_ID."
  type        = string
}

variable "apim_resource_group" {
  description = "Resource group of the AI gateway. GitHub variable APIM_RESOURCE_GROUP."
  type        = string
}

variable "apim_name" {
  description = "The AI gateway (APIM instance). GitHub variable APIM_NAME."
  type        = string
}

variable "models_product" {
  description = "APIM product of the model catalog and the projects' model APIs. GitHub variable MODELS_PRODUCT."
  type        = string
  default     = "platform-models"
}

variable "content_safety_account" {
  description = "Azure AI Content Safety account the gateway checks prompts with. GitHub variable CONTENT_SAFETY_ACCOUNT."
  type        = string
  default     = ""
}

variable "content_safety_resource_group" {
  description = "Its resource group. GitHub variable CONTENT_SAFETY_RESOURCE_GROUP."
  type        = string
  default     = ""
}

variable "app_insights_name" {
  description = "Application Insights for gateway telemetry and token metrics (optional). GitHub variable APP_INSIGHTS_NAME."
  type        = string
  default     = ""
}

variable "app_insights_resource_group" {
  description = "Its resource group. GitHub variable APP_INSIGHTS_RESOURCE_GROUP."
  type        = string
  default     = ""
}
