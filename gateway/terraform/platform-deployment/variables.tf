variable "environment" {
  description = "Environment name (dev, uat, prd)."
  type        = string
  default     = "dev"
}

# Platform coordinates of the environment: GitHub environment variables (model-<environment>), passed by the workflow
# as TF_VAR_*. Nothing about an environment is kept in this repository.
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

variable "portal_anonymous" {
  description = "Developer Portal: products visible without sign-in. GitHub variable PORTAL_ANONYMOUS."
  type        = bool
  default     = false
}
