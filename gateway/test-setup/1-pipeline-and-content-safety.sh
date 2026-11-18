#!/usr/bin/env bash
# One-time setup so both repositories' pipelines can deploy to the test environment (scbx-testing).
# Adds only: one Content Safety account, role assignments, two federated credentials, GitHub environment variables.
set -euo pipefail
S=3471ad5a-d8a8-4a80-b30b-668798733c14
RG=az-rg-tst-model-npr-01
CS=cs-tst-3471ad
PIPELINE_PRINCIPAL=9f5af523-3e28-4b80-86e7-26b5926ba86a     # id-promptops-pipeline (client 052d6104-…)
PIPELINE_CLIENT=052d6104-7b4c-4705-b1a5-2f4a769c32ec
TENANT=7b180d87-6e3e-4bc3-9372-0ab40c6997bb

echo "== 1. Content Safety account $CS (gateway prompt checks)"
az cognitiveservices account show -n $CS -g $RG --subscription $S -o none 2>/dev/null \
  || az cognitiveservices account create -n $CS -g $RG --kind ContentSafety --sku S0 -l eastus2 \
       --custom-domain $CS --subscription $S --yes -o none
CSID=$(az cognitiveservices account show -n $CS -g $RG --subscription $S --query id -o tsv)

echo "== 2. APIM managed identity: Cognitive Services User on $CS"
APIM_MI=$(az apim show -g $RG -n apim-agents-3471ad --subscription $S --query identity.principalId -o tsv)
az role assignment create --assignee-object-id $APIM_MI --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services User" --scope $CSID -o none

echo "== 3. Pipeline identity: Contributor on $RG, Storage Blob Data Contributor on the Terraform state"
az role assignment create --assignee-object-id $PIPELINE_PRINCIPAL --assignee-principal-type ServicePrincipal \
  --role Contributor --scope /subscriptions/$S/resourceGroups/$RG -o none
az role assignment create --assignee-object-id $PIPELINE_PRINCIPAL --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show -n stscbxtf3471ad5a --subscription $S --query id -o tsv)" -o none

echo "== 4. Pipeline identity trusts the model-test GitHub environment of both repositories"
for pair in "ai-gateway@1461055534" "agent-deployment@1445709242"; do
  repo=${pair%@*}
  az identity federated-credential show -g $RG --identity-name id-promptops-pipeline --subscription $S \
       -n github-$repo-model-test -o none 2>/dev/null \
    || az identity federated-credential create -g $RG --identity-name id-promptops-pipeline --subscription $S \
         -n github-$repo-model-test --issuer https://token.actions.githubusercontent.com \
         --audiences api://AzureADTokenExchange \
         --subject "repo:DeepuMM@3176338/$pair:environment:model-test" -o none
done

echo "== 5. GitHub: model-test environment in both repositories; MODEL_ENVIRONMENTS=sandbox,test"
for repo in ai-gateway agent-deployment; do
  gh api -X PUT repos/DeepuMM/$repo/environments/model-test >/dev/null
  gh variable set AZURE_CLIENT_ID       -R DeepuMM/$repo --env model-test -b $PIPELINE_CLIENT
  gh variable set AZURE_TENANT_ID       -R DeepuMM/$repo --env model-test -b $TENANT
  gh variable set AZURE_SUBSCRIPTION_ID -R DeepuMM/$repo --env model-test -b $S
  gh variable set MODEL_ENVIRONMENTS    -R DeepuMM/$repo -b "sandbox,test"
done
echo "done"
