#!/usr/bin/env bash
# Lets the test gateway (APIM's managed identity) pass the caller's identity to hosted agents (header x-ms-user-identity),
# so Foundry isolates sessions and conversations per caller. No built-in role has this data action.
# Adds only: one custom role definition (subscription-scoped definition) and one role assignment on the agent account.
set -euo pipefail
S=3471ad5a-d8a8-4a80-b30b-668798733c14
RG=az-rg-tst-model-npr-01
AGENTS=az-aif-tst-model-npr-01
ROLE="Foundry Agent User Identity Impersonation"

echo "== 1. Custom role: $ROLE"
if ! az role definition list --name "$ROLE" --subscription $S --query "[0].id" -o tsv | grep -q .; then
  az role definition create --subscription $S --role-definition "{
    \"Name\": \"$ROLE\",
    \"IsCustom\": true,
    \"Description\": \"Lets a trusted middle tier (the AI gateway) pass the end user's identity to hosted agents via x-ms-user-identity.\",
    \"Actions\": [],
    \"NotActions\": [],
    \"DataActions\": [\"Microsoft.CognitiveServices/accounts/AIServices/agents/endpoints/UserIdentityImpersonation/action\"],
    \"NotDataActions\": [],
    \"AssignableScopes\": [\"/subscriptions/$S/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$AGENTS\"]
  }" -o none
  echo "   created; waiting 60s for it to replicate"; sleep 60
fi

echo "== 2. APIM managed identity: $ROLE on the agent account $AGENTS"
APIM_MI=$(az apim show -g $RG -n apim-agents-3471ad --subscription $S --query identity.principalId -o tsv)
az role assignment create --assignee-object-id $APIM_MI --assignee-principal-type ServicePrincipal --role "$ROLE" \
  --scope "$(az cognitiveservices account show -n $AGENTS -g $RG --subscription $S --query id -o tsv)" -o none
echo "done"
