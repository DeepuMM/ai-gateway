"""What a platform release must do, for the release workflow (.github/workflows/_release.yml).

  release_plan.py <environments> [--all] [--base <sha>]

<environments>: the repository variable PLATFORM_ENVIRONMENTS, comma-separated in promotion order (e.g. "dev" or
"dev,uat,prd"). Prints key=value lines for $GITHUB_OUTPUT:
  environments  JSON list of those environments
  policies      true when the gateway policy unit must run: --all, or gateway/policy-fragments/ or
                gateway/terraform/gateway-policies/ changed since <base>
  models        true when the models unit must run: --all, or gateway/foundry-accounts/ or
                gateway/terraform/platform-deployment/ changed since <base>

--all (manual runs, release tags) or no usable base: everything.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POLICIES = ("gateway/policy-fragments/", "gateway/terraform/gateway-policies/")
MODELS = ("gateway/foundry-accounts/", "gateway/terraform/platform-deployment/")


def main(argv):
    envs = [e.strip() for e in argv[0].split(",") if e.strip()] or ["dev"]
    base = argv[argv.index("--base") + 1] if "--base" in argv and argv.index("--base") + 1 < len(argv) else ""
    files = None
    if "--all" not in argv and base and set(base) != {"0"}:
        r = subprocess.run(["git", "diff", "--name-only", base, "HEAD"], capture_output=True, text=True, cwd=ROOT)
        files = None if r.returncode else r.stdout.splitlines()
    policies = files is None or any(f.startswith(POLICIES) for f in files)
    models = files is None or any(f.startswith(MODELS) for f in files)
    print(f"environments={json.dumps(envs)}")
    print(f"policies={str(policies).lower()}")
    print(f"models={str(models).lower()}")


if __name__ == "__main__":
    if not sys.argv[1:]:
        sys.exit(__doc__)
    main(sys.argv[1:])
