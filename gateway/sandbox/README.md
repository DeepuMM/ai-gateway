# Sandbox (disposable)

A throw-away environment to test the pipelines end to end, in one resource group (`rg-ai-gateway-sandbox`): a
model-hosting Foundry account (models only), an agent-only Foundry account (its projects are created by the project
repository's use-case onboarding), an APIM (Basic v2), an Azure AI Content Safety account (gateway prompt checks;
APIM's managed identity gets Cognitive Services User on it), a storage account for Terraform state, and the pipeline
identity `id-sbx-pipeline` trusted by both repositories' `sandbox` GitHub environments. Local state, not shared: keep
`terraform.tfstate` in this folder (it is not in Git).

```bash
cd gateway/sandbox
terraform init
terraform apply -var subscription_id=<sub> -var publisher_email=<you> \
  -var github_oidc_subject=<project repo subject> -var gateway_github_oidc_subject=<gateway repo subject>
terraform output -raw environment_file > ../../platform/environments/sandbox.yaml   # copy it to the project repository too
# add gateway/foundry-accounts/<hosting_account>/, then run, in this order:
#   here: model-platform-deployment, gateway-policy-deployment
#   project repository: use-case-onboarding, agent-deploy
terraform destroy -var subscription_id=<sub> -var publisher_email=<you> ...   # removes everything
```
