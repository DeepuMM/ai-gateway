locals {
  repo_root = "${path.module}/../../.."
  env       = yamldecode(file("${local.repo_root}/platform/environments/${var.environment}.yaml"))

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
