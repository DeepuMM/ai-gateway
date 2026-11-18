# Test environment setup (scbx-testing): one-time permission scripts

What the pipelines need in an environment but can't create themselves (the pipeline identity can't assign roles).
A subscription Owner runs them once per environment, in this order, before the first pipeline run. They only add
resources and role assignments, and are safe to re-run (existing resources are skipped; an existing role assignment
is reported by `az`). These are the dev environment's (formerly `test`; its coordinates are the GitHub variables of `model-dev`); copy and adjust the names
for another environment.

| Script | Adds |
|---|---|
| `1-pipeline-and-content-safety.sh` | Content Safety account `cs-tst-3471ad` + APIM's Cognitive Services User on it; pipeline identity `id-promptops-pipeline`: Contributor on `az-rg-tst-model-npr-01`, Storage Blob Data Contributor on the Terraform state, OIDC trust for both repositories' `model-test` GitHub environments; the `model-test` environments and `MODEL_ENVIRONMENTS` (since set to `test` only) |
| `2-models-account.sh` | models-only Foundry account `aif-tst-models-3471ad` (key auth off) + Foundry User for APIM and the pipeline identity; Cognitive Services User on `cs-tst-3471ad` for the person running it (used to calibrate the content-safety proof prompt) |
| `3-user-identity-impersonation.sh` | custom role **Foundry Agent User Identity Impersonation** (data action `…/agents/endpoints/UserIdentityImpersonation/action`) for APIM's identity on the agent account, so the gateway can pass the caller's identity to hosted agents (`x-ms-user-identity`) |

Moving a model from one hosting account to another: remove the old deployment from the model state first
(`terraform state rm 'azurerm_cognitive_deployment.model["<model>"]'` in `gateway/terraform/platform-deployment`
with the environment's backend), so the move creates the new deployment without deleting the old one. In test, the
deployments made in the agent account before the platform (`az-aif-tst-model-npr-01`) are kept and are not managed.
