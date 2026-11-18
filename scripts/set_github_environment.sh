#!/usr/bin/env bash
# Sets an environment's coordinates as variables on its GitHub environment model-<env> (this repository's pipelines
# read only these; nothing about an environment is kept in the repository). Values are not secret. Run by a platform
# engineer when an environment is created or changes (needs admin on the repository: gh auth login). An existing
# GitHub environment keeps its protection rules (required reviewers).
#
#   scripts/set_github_environment.sh <env> KEY=VALUE ...
#
# Keys (all required unless marked):
#   AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID   pipeline sign-in (federated credential for model-<env>)
#   APIM_SUBSCRIPTION_ID APIM_RESOURCE_GROUP APIM_NAME [MODELS_PRODUCT=platform-models] [PORTAL_ANONYMOUS=false]
#   CONTENT_SAFETY_ACCOUNT CONTENT_SAFETY_RESOURCE_GROUP
#   [APP_INSIGHTS_NAME APP_INSIGHTS_RESOURCE_GROUP]        gateway telemetry and token metrics (optional)
#   TF_STATE_RESOURCE_GROUP TF_STATE_STORAGE_ACCOUNT TF_STATE_CONTAINER
set -euo pipefail
env_name=${1:?usage: set_github_environment.sh <env> KEY=VALUE ...}; shift
required=(AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID APIM_SUBSCRIPTION_ID APIM_RESOURCE_GROUP APIM_NAME
          CONTENT_SAFETY_ACCOUNT CONTENT_SAFETY_RESOURCE_GROUP TF_STATE_RESOURCE_GROUP TF_STATE_STORAGE_ACCOUNT TF_STATE_CONTAINER)
declare -A values=([MODELS_PRODUCT]=platform-models [PORTAL_ANONYMOUS]=false)
for kv in "$@"; do values[${kv%%=*}]=${kv#*=}; done
for k in "${required[@]}"; do [ -n "${values[$k]:-}" ] || { echo "missing $k" >&2; exit 1; }; done
gh_env="model-$env_name"
gh api "repos/{owner}/{repo}/environments/$gh_env" --silent 2>/dev/null \
  || gh api -X PUT "repos/{owner}/{repo}/environments/$gh_env" --silent
for k in "${!values[@]}"; do gh variable set "$k" --env "$gh_env" --body "${values[$k]}"; done
echo "$gh_env: ${#values[@]} variables set"
