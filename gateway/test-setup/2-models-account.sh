#!/usr/bin/env bash
# Split test: a model-hosting Foundry account (models only) next to the agent account az-aif-tst-model-npr-01.
# Adds only: one Foundry account and role assignments. The model deployment itself is made by the ai-gateway pipeline.
set -euo pipefail
S=3471ad5a-d8a8-4a80-b30b-668798733c14
RG=az-rg-tst-model-npr-01
MODELS=aif-tst-models-3471ad
PIPELINE_PRINCIPAL=9f5af523-3e28-4b80-86e7-26b5926ba86a     # id-promptops-pipeline

echo "== 1. Model-hosting Foundry account $MODELS (models only, Entra ID auth only)"
az cognitiveservices account show -n $MODELS -g $RG --subscription $S -o none 2>/dev/null \
  || az cognitiveservices account create -n $MODELS -g $RG --kind AIServices --sku S0 -l eastus2 \
       --custom-domain $MODELS --subscription $S --yes -o none
az resource update --ids "$(az cognitiveservices account show -n $MODELS -g $RG --subscription $S --query id -o tsv)" \
  --set properties.disableLocalAuth=true -o none
MID=$(az cognitiveservices account show -n $MODELS -g $RG --subscription $S --query id -o tsv)

echo "== 2. APIM managed identity: Foundry User on $MODELS (the gateway calls the models)"
APIM_MI=$(az apim show -g $RG -n apim-agents-3471ad --subscription $S --query identity.principalId -o tsv)
az role assignment create --assignee-object-id $APIM_MI --assignee-principal-type ServicePrincipal \
  --role "Foundry User" --scope $MID -o none

echo "== 3. Pipeline identity: Foundry User on $MODELS (model smoke test)"
az role assignment create --assignee-object-id $PIPELINE_PRINCIPAL --assignee-principal-type ServicePrincipal \
  --role "Foundry User" --scope $MID -o none

echo "== 4. You: Cognitive Services User on cs-tst-3471ad (to calibrate the content-safety proof prompt)"
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id $ME --assignee-principal-type User --role "Cognitive Services User" \
  --scope "$(az cognitiveservices account show -n cs-tst-3471ad -g $RG --subscription $S --query id -o tsv)" -o none
echo "done"
