#!/usr/bin/env python3
"""One-time Entra setup of the AI gateway's agent app for ONE environment. Run by a tenant admin, not by a pipeline.

Callers of agents through the gateway present a token for this app (scope `<client ID>/.default` or
`api://ai-gateway-agents-<env>/.default`); the agent-caller policy fragment lets a call through only if the token's
`roles` claim holds the agent's role. The agent pipeline (agent-deployment) creates those roles on this app; who gets
which role is decided outside the pipelines, by the agents' owners and the tenant admins (README: Access to agents).

  python3 scripts/setup_agents_app.py <environment> <pipeline identity client ID>

Creates or completes, idempotently:
  - app registration "AI Gateway Agents (<env>)", URI api://ai-gateway-agents-<env> (falls back to api://<client ID>
    when the tenant refuses that URI), v2 tokens, delegated scope access_as_user, Azure CLI pre-authorized
  - its enterprise app with "assignment required": only identities holding one of its roles get a token at all
  - role agents.all (call every agent), assigned to the pipeline identity: its smoke tests call every agent
  - the pipeline identity as owner of the app, and Microsoft Graph Application.ReadWrite.OwnedBy for it: it can
    create and remove agent roles on the apps it owns, and on nothing else in the tenant
Prints the client ID: set it as GitHub variable AGENTS_APP_ID (both repositories' environments).

Needs `az login` as a user who may create app registrations and grant Microsoft Graph application permissions
(Privileged Role Administrator or Global Administrator).
"""
import json
import subprocess
import sys
import uuid

GRAPH = "https://graph.microsoft.com/v1.0"
GRAPH_APP_ID = "00000003-0000-0000-c000-000000000000"
AZURE_CLI_APP_ID = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"


def az(*args, ok_fail=False):
    r = subprocess.run(["az", *args, "-o", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        if ok_fail:
            return None
        sys.exit(f"az {' '.join(args[:3])} ...: {r.stderr.strip()[:600]}")
    return json.loads(r.stdout) if r.stdout.strip() else {}


def graph(method, path, body=None, ok_fail=False):
    args = ["rest", "--method", method, "--url", f"{GRAPH}/{path}"]
    if body is not None:
        args += ["--headers", "Content-Type=application/json", "--body", json.dumps(body)]
    return az(*args, ok_fail=ok_fail)


def main(env_name, pipeline_client_id):
    name, uri = f"AI Gateway Agents ({env_name})", f"api://ai-gateway-agents-{env_name}"

    apps = graph("GET", f"applications?$filter=displayName eq '{name}'&$select=id,appId")["value"]
    if apps:
        app = apps[0]
        print(f"app registration {name}: exists ({app['appId']})")
    else:
        app = graph("POST", "applications", {"displayName": name, "signInAudience": "AzureADMyOrg"})
        print(f"app registration {name}: created ({app['appId']})")
    app_id, app_oid = app["appId"], app["id"]
    full = graph("GET", f"applications/{app_oid}?$select=identifierUris,api,appRoles")

    # Identifier URI: the readable one, or api://<client ID> where tenant policy requires it. Callers can always use
    # <client ID>/.default as the scope; the gateway checks the client ID (v2 token audience).
    if not full.get("identifierUris"):
        if graph("PATCH", f"applications/{app_oid}", {"identifierUris": [uri]}, ok_fail=True) is None:
            uri = f"api://{app_id}"
            graph("PATCH", f"applications/{app_oid}", {"identifierUris": [uri]})
        print(f"  identifier URI {uri}")
    else:
        uri = full["identifierUris"][0]

    # v2 tokens (audience = client ID) and the delegated scope users' tools (Azure CLI, MSAL) ask for.
    api = full.get("api") or {}
    scopes = api.get("oauth2PermissionScopes") or []
    scope = next((s for s in scopes if s["value"] == "access_as_user"), None)
    if scope is None:
        scope = {"id": str(uuid.uuid4()), "value": "access_as_user", "type": "User", "isEnabled": True,
                 "adminConsentDisplayName": "Call AI gateway agents as the signed-in user",
                 "adminConsentDescription": "Call the agents the signed-in user holds a role for, through the AI gateway.",
                 "userConsentDisplayName": "Call AI gateway agents as you",
                 "userConsentDescription": "Call the agents you hold a role for, through the AI gateway."}
        scopes = scopes + [scope]
    graph("PATCH", f"applications/{app_oid}", {"api": {"requestedAccessTokenVersion": 2, "oauth2PermissionScopes": scopes}})
    graph("PATCH", f"applications/{app_oid}", {"api": {"preAuthorizedApplications": [
        {"appId": AZURE_CLI_APP_ID, "delegatedPermissionIds": [scope["id"]]}]}})
    print("  v2 tokens, scope access_as_user, Azure CLI pre-authorized")

    # Role agents.all; the agent pipeline adds agent.<project>.all and agent.<project>.<agent> next to it.
    roles = full.get("appRoles") or []
    all_role = next((r for r in roles if r["value"] == "agents.all"), None)
    if all_role is None:
        all_role = {"id": str(uuid.uuid4()), "value": "agents.all", "isEnabled": True,
                    "allowedMemberTypes": ["User", "Application"], "displayName": "Call every agent",
                    "description": "Call every agent on the AI gateway (platform and pipeline smoke tests)."}
        graph("PATCH", f"applications/{app_oid}", {"appRoles": roles + [all_role]})
        print("  role agents.all: created")

    # Enterprise app with assignment required.
    sps = graph("GET", f"servicePrincipals?$filter=appId eq '{app_id}'&$select=id")["value"]
    sp_oid = sps[0]["id"] if sps else graph("POST", "servicePrincipals", {"appId": app_id})["id"]
    graph("PATCH", f"servicePrincipals/{sp_oid}", {"appRoleAssignmentRequired": True})
    print("  enterprise app: assignment required")

    # The pipeline identity: owner of the app, Graph Application.ReadWrite.OwnedBy, role agents.all.
    pipe = graph("GET", f"servicePrincipals?$filter=appId eq '{pipeline_client_id}'&$select=id,displayName")["value"]
    if not pipe:
        sys.exit(f"No service principal with client ID {pipeline_client_id} (the pipeline identity, GitHub variable AZURE_CLIENT_ID)")
    pipe_oid = pipe[0]["id"]
    owners = [o["id"] for o in graph("GET", f"applications/{app_oid}/owners?$select=id")["value"]]
    if pipe_oid not in owners:
        graph("POST", f"applications/{app_oid}/owners/$ref", {"@odata.id": f"{GRAPH}/directoryObjects/{pipe_oid}"})
    print(f"  owner: {pipe[0]['displayName']}")

    graph_sp = graph("GET", f"servicePrincipals?$filter=appId eq '{GRAPH_APP_ID}'&$select=id,appRoles")["value"][0]
    owned_by = next(r["id"] for r in graph_sp["appRoles"] if r["value"] == "Application.ReadWrite.OwnedBy")
    have = graph("GET", f"servicePrincipals/{pipe_oid}/appRoleAssignments")["value"]
    granted = any(a["appRoleId"] == owned_by and a["resourceId"] == graph_sp["id"] for a in have)
    if not granted:
        granted = graph("POST", f"servicePrincipals/{pipe_oid}/appRoleAssignments",
                        {"principalId": pipe_oid, "resourceId": graph_sp["id"], "appRoleId": owned_by},
                        ok_fail=True) is not None
    if granted:
        print("  pipeline identity: Microsoft Graph Application.ReadWrite.OwnedBy")
    else:   # granting Graph application permissions needs Privileged Role Administrator or Global Administrator
        body = json.dumps({"principalId": pipe_oid, "resourceId": graph_sp["id"], "appRoleId": owned_by})
        print("  pipeline identity: Microsoft Graph Application.ReadWrite.OwnedBy NOT granted: your account can't grant\n"
              "  Microsoft Graph application permissions. A Privileged Role Administrator or Global Administrator runs:\n"
              f"    az rest --method POST --url {GRAPH}/servicePrincipals/{pipe_oid}/appRoleAssignments --body '{body}'")
    if not any(a["appRoleId"] == all_role["id"] and a["resourceId"] == sp_oid for a in have):
        graph("POST", f"servicePrincipals/{sp_oid}/appRoleAssignedTo",
              {"principalId": pipe_oid, "resourceId": sp_oid, "appRoleId": all_role["id"]})
    print("  pipeline identity: role agents.all")

    print(f"\nAGENTS_APP_ID={app_id}\ncallers' scope: {uri}/.default (or {app_id}/.default)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
