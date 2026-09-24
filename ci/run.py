"""GitLab shell-runner entry point. Uses only Python's standard library."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
TOFU_VERSION = "1.12.5"
PLAN_TTL_SECONDS = 3600
TEST_MODULES = {
    "modules/azure/compute": "live/azure/aira/dev/centralindia/data",
    "modules/azure/mysql": "live/azure/aira/dev/centralindia/data",
    "modules/azure/cache": "live/azure/aira/dev/centralindia/data",
    "modules/aws/recordings": "live/aws/aira/dev/ap-south-1/recordings",
}


def required(env, name):
    value = env.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing required CI variable: {name}")
    return value


def targets():
    return json.loads((REPO / "ci/targets.json").read_text())


def resolve_target(name):
    registry = targets()
    if name not in registry:
        raise ValueError("Unknown DEPLOY_TARGET; choose an ID from ci/targets.json.")
    target = dict(registry[name])
    path = Path(target["root"])
    parts = path.parts
    if (len(parts) != 6 or parts[0] != "live" or parts[1] not in ("azure", "aws")
            or ".." in parts or not (REPO / path).resolve().is_relative_to(REPO)):
        raise ValueError("Target must be a live/<cloud>/<deployment>/<env>/<region>/<component> root.")
    if not (REPO / path / ".terraform.lock.hcl").is_file():
        raise ValueError("Target is missing its committed provider lock file.")
    target.update(id=name, cloud=parts[1], deployment=parts[2], environment=parts[3],
                  region=parts[4], component=parts[5],
                  state_key="/".join(parts[1:-1]) + "/" + parts[-1] + ".tfstate")
    if target["cloud"] == "azure":
        settings = json.loads((REPO / path.parent / "deployment.json").read_text())
        for field, expected in (("deployment_id", parts[2]), ("environment", parts[3]), ("location", parts[4])):
            if settings[field] != expected:
                raise ValueError(f"Deployment JSON {field} disagrees with the target path.")
    return target


def deployment_guard(env):
    if (env.get("RUN_DEPLOYMENT") != "true"
            or env.get("CI_PIPELINE_SOURCE") != "web"
            or env.get("CI_COMMIT_REF_PROTECTED") != "true"
            or not env.get("CI_DEFAULT_BRANCH")
            or env.get("CI_COMMIT_BRANCH") != env.get("CI_DEFAULT_BRANCH")):
        raise ValueError("Deployments require a manually started pipeline on the protected default branch.")


def run(args, env, capture=False):
    result = subprocess.run(args, cwd=REPO, env=env, text=True,
                            stdout=subprocess.PIPE if capture else None, check=False)
    if result.returncode:
        raise RuntimeError(f"{args[0]} {args[1]} failed (exit {result.returncode}).")
    return result.stdout if capture else None


def check():
    if sys.version_info < (3, 9):
        raise ValueError("Python 3.9 or newer is required on the shell runner.")
    if not shutil.which("tofu"):
        raise ValueError("Install OpenTofu 1.12.5 on the shell runner PATH.")
    output = run(["tofu", "version", "-json"], os.environ.copy(), capture=True)
    if json.loads(output)["terraform_version"] != TOFU_VERSION:
        raise ValueError(f"Runner must use OpenTofu {TOFU_VERSION}.")
    print(f"OpenTofu {TOFU_VERSION}; Python {sys.version.split()[0]}", flush=True)


def base_env():
    env = os.environ.copy()
    # Job behavior comes from this script, not runner-local OpenTofu flags/workspaces.
    for key in list(env):
        if key.startswith("TF_CLI_ARGS"):
            del env[key]
    env.update(TF_IN_AUTOMATION="true", TF_INPUT="false", TF_WORKSPACE="default")
    return env


def root_env(env, work, root):
    result = env.copy()
    path = work / "data" / root
    path.mkdir(parents=True, exist_ok=True)
    result["TF_DATA_DIR"] = str(path)
    return result


def tofu(root, *args):
    return ["tofu", f"-chdir={root}", *args]


def validate(env, work):
    run(["tofu", "fmt", "-check", "-recursive"], env)
    roots = ["bootstrap/azure"] + [entry["root"] for entry in targets().values()]
    for root in dict.fromkeys(roots):
        current = root_env(env, work, root)
        run(tofu(root, "init", "-backend=false", "-input=false", "-lockfile=readonly", "-no-color"), current)
        run(tofu(root, "validate", "-no-color"), current)
    # Detect path/metadata mistakes before any deployment.
    for name in targets():
        resolve_target(name)


def test(env, work):
    for module, lock_source in TEST_MODULES.items():
        # Modules inherit the same pinned provider as deployed roots.
        shutil.copyfile(REPO / lock_source / ".terraform.lock.hcl",
                        REPO / module / ".terraform.lock.hcl")
        current = root_env(env, work, module)
        run(tofu(module, "init", "-backend=false", "-input=false", "-lockfile=readonly", "-no-color"), current)
        run(tofu(module, "test", "-no-color"), current)


def cloud_auth(env, target, work):
    env = env.copy()
    for name in ("ARM_CLIENT_ID", "ARM_TENANT_ID", "ARM_SUBSCRIPTION_ID"):
        required(env, name)
    env.update(ARM_USE_AZUREAD="true", ARM_USE_CLI="false", ARM_USE_MSI="false")
    mode = env.get("AZURE_AUTH_MODE", "oidc")
    if mode == "oidc":
        env["ARM_USE_OIDC"] = "true"
        env["ARM_OIDC_TOKEN"] = required(env, "AZURE_ID_TOKEN")
        env.pop("ARM_CLIENT_SECRET", None)
    elif mode == "client_secret":
        required(env, "ARM_CLIENT_SECRET")
        env["ARM_USE_OIDC"] = "false"
        env.pop("ARM_OIDC_TOKEN", None)
    else:
        raise ValueError("AZURE_AUTH_MODE must be oidc or client_secret.")
    if target["cloud"] == "aws":
        mode = env.get("AWS_AUTH_MODE", "oidc")
        env["AWS_EC2_METADATA_DISABLED"] = "true"
        env["AWS_REGION"] = target["region"]
        env["AWS_DEFAULT_REGION"] = target["region"]
        if mode == "oidc":
            required(env, "AWS_ROLE_ARN")
            token_file = work / "aws-identity-token"
            token_file.write_text(required(env, "AWS_ID_TOKEN"))
            token_file.chmod(0o600)
            env["AWS_WEB_IDENTITY_TOKEN_FILE"] = str(token_file)
            env["AWS_ROLE_SESSION_NAME"] = "gitlab-" + required(env, "CI_PIPELINE_ID") + "-" + required(env, "CI_JOB_ID")
            for name in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN", "AWS_PROFILE"):
                env.pop(name, None)
        elif mode == "environment":
            required(env, "AWS_ACCESS_KEY_ID")
            required(env, "AWS_SECRET_ACCESS_KEY")
            env.pop("AWS_WEB_IDENTITY_TOKEN_FILE", None)
            env.pop("AWS_PROFILE", None)
        else:
            raise ValueError("AWS_AUTH_MODE must be oidc or environment.")
    return env


def backend_config(env, target):
    return {
        "resource_group_name": required(env, "STATE_RESOURCE_GROUP"),
        "storage_account_name": required(env, "STATE_STORAGE_ACCOUNT"),
        "container_name": required(env, "STATE_CONTAINER"),
        "key": target["state_key"],
        "use_azuread_auth": True,
    }


def plan_inputs(env, target, backend):
    env = env.copy()
    component = target["component"]
    if target["cloud"] == "azure":
        if component in ("data", "application"):
            env["TF_VAR_state_backend"] = json.dumps({key: backend[key] for key in
                ("resource_group_name", "storage_account_name", "container_name")})
        if component == "data":
            for name in ("TF_VAR_key_vault_name", "TF_VAR_mysql_password"):
                required(env, name)
        if component == "application":
            for name in ("TF_VAR_ssh_public_key", "TF_VAR_ubuntu_image_version"):
                required(env, name)
            env.setdefault("TF_VAR_admin_cidrs", "[]")
    else:
        for name in ("TF_VAR_aws_account_id", "TF_VAR_bucket_name"):
            required(env, name)
        env.update(TF_VAR_region=target["region"], TF_VAR_deployment_id=target["deployment"],
                   TF_VAR_environment=target["environment"])
    return env


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity(env, target, backend):
    return {
        "target": target["id"],
        "root": target["root"],
        "pipeline": required(env, "CI_PIPELINE_ID"),
        "commit": required(env, "CI_COMMIT_SHA"),
        "project": required(env, "CI_PROJECT_ID"),
        "backend": backend,
        "azure_subscription": required(env, "ARM_SUBSCRIPTION_ID"),
        "azure_tenant": required(env, "ARM_TENANT_ID"),
        "tofu_version": TOFU_VERSION,
    }


def verify_plan(metadata, expected, plan_file, now=None):
    for key, value in expected.items():
        if metadata.get(key) != value:
            raise ValueError(f"Saved plan does not match this job ({key}). Start a new pipeline.")
    age = (time.time() if now is None else now) - metadata["created_at"]
    if age < 0 or age > PLAN_TTL_SECONDS:
        raise ValueError("Saved plan expired. Start a new pipeline for a fresh review.")
    if metadata.get("sha256") != sha256(plan_file):
        raise ValueError("Saved plan checksum mismatch; refusing apply.")


def deploy(action, env, work):
    deployment_guard(env)
    target = resolve_target(required(env, "DEPLOY_TARGET"))
    backend = backend_config(env, target)
    expected = identity(env, target, backend)
    artifacts = REPO / ".ci-plan"
    plan_file = artifacts / "deployment.tfplan"
    metadata_file = artifacts / "metadata.json"
    if action == "apply":
        # Check the artifact before any cloud access. Apply never generates another plan.
        verify_plan(json.loads(metadata_file.read_text()), expected, plan_file)
    env = cloud_auth(env, target, work)
    if action == "plan":
        env = plan_inputs(env, target, backend)
    backend_file = work / "backend.hcl"
    backend_file.write_text("\n".join(f"{key} = {json.dumps(value)}" for key, value in backend.items()) + "\n")
    current = root_env(env, work, target["root"])
    run(tofu(target["root"], "init", "-input=false", "-reconfigure", "-lockfile=readonly",
             "-no-color", f"-backend-config={backend_file}"), current)
    if action == "plan":
        artifacts.mkdir(exist_ok=True)
        artifacts.chmod(0o700)
        if target["requires"]:
            print("Prerequisite targets must already be applied: " + ", ".join(target["requires"]), flush=True)
        run(tofu(target["root"], "plan", "-input=false", "-lock-timeout=5m",
                 "-no-color", f"-out={plan_file}"), current)
        plan_file.chmod(0o600)
        metadata_file.write_text(json.dumps(dict(expected, created_at=time.time(),
                                                 sha256=sha256(plan_file)), indent=2) + "\n")
        metadata_file.chmod(0o600)
    else:
        run(tofu(target["root"], "apply", "-input=false", "-lock-timeout=5m",
                 "-no-color", str(plan_file)), current)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("check", "validate", "test", "plan", "apply"))
    args = parser.parse_args()
    check()
    if args.action == "check":
        return
    os.umask(0o077)
    # Job-local provider/backend metadata and tokens are never cached or artifacted.
    work_root = REPO / ".ci-work"
    work_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="job-", dir=work_root) as temp:
        work = Path(temp)
        env = base_env()
        if args.action == "validate":
            validate(env, work)
        elif args.action == "test":
            test(env, work)
        else:
            deploy(args.action, env, work)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError, KeyError) as error:
        print(f"CI error: {error}", file=sys.stderr)
        sys.exit(1)
