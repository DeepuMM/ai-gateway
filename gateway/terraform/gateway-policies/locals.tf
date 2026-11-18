locals {
  repo_root = "${path.module}/../../.."
  # The environment's coordinates, from the platform variables (GitHub environment variables).
  env = {
    tenant_id = var.tenant_id
    gateway = {
      subscription_id = var.apim_subscription_id
      resource_group  = var.apim_resource_group
      apim_name       = var.apim_name
      models_product  = var.models_product
      content_safety  = var.content_safety_account != "" ? { account_name = var.content_safety_account, resource_group = var.content_safety_resource_group } : null
      app_insights    = var.app_insights_name != "" ? { name = var.app_insights_name, resource_group = var.app_insights_resource_group } : null
    }
  }

  # Azure AI Content Safety account the model-content-safety fragment calls (required in every environment file).
  content_safety_set = can(local.env.gateway.content_safety.account_name) && can(local.env.gateway.content_safety.resource_group)
  content_safety     = local.content_safety_set ? local.env.gateway.content_safety : { account_name = "not-set", resource_group = "not-set" }

  # Application Insights the gateway sends telemetry and token metrics to (optional: gateway.app_insights).
  app_insights_set = can(local.env.gateway.app_insights.name) && can(local.env.gateway.app_insights.resource_group)

  # gateway/policy-fragments/<id>.xml -> APIM policy fragment <id>.
  fragments_dir = "${local.repo_root}/gateway/policy-fragments"
  policy_fragments = {
    for f in fileset(local.fragments_dir, "*.xml") : trimsuffix(f, ".xml") => file("${local.fragments_dir}/${f}")
  }

}
