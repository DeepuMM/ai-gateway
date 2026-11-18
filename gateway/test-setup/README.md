# Test environment setup (scbx-testing): one-time permission scripts

The test environment (`platform/environments/test.yaml`) existed before these pipelines; these scripts add what the
pipelines need and can't do themselves (the pipeline identity can't assign roles). Each was run once, on
2026-11-17, by a subscription Owner, in this order. They only add resources and role assignments, and are safe to
re-run (existing resources are skipped; an existing role assignment is reported by `az`).

| Script | Adds |
|---|---|
| `1-pipeline-and-content-safety.sh` | Content Safety account `cs-tst-3471ad` + APIM's Cognitive Services User on it; pipeline identity `id-promptops-pipeline`: Contributor on `az-rg-tst-model-npr-01`, Storage Blob Data Contributor on the Terraform state, OIDC trust for both repositories' `model-test` GitHub environments; the `model-test` environments and `MODEL_ENVIRONMENTS` (since set to `test` only) |
| `2-models-account.sh` | models-only Foundry account `aif-tst-models-3471ad` (key auth off) + Foundry User for APIM and the pipeline identity; Cognitive Services User on `cs-tst-3471ad` for the person running it (used to calibrate the content-safety proof prompt) |
| `3-user-identity-impersonation.sh` | custom role **Foundry Agent User Identity Impersonation** (data action `…/agents/endpoints/UserIdentityImpersonation/action`) for APIM's identity on the agent account, so the gateway can pass the caller's identity to hosted agents (`x-ms-user-identity`) |

Not scripted: `terraform state rm` of the old `gpt-5.4-mini` deployment from the test model state before the
models-only split (the deployment in `az-aif-tst-model-npr-01` was kept, unmanaged).
