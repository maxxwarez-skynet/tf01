# GitLab CI/CD

The pipeline targets the existing **Linux shell executor**. Jobs run directly on
the runner host; no Docker image is used.

## Pipeline behavior

- Branch pushes and merge requests: formatting, root validation, CI helper tests,
  and mocked OpenTofu tests. No deployment ID tokens are issued to these jobs.
- A manually started pipeline on the protected default branch, with
  `RUN_DEPLOYMENT=true`: the same checks, then a real plan for `DEPLOY_TARGET`.
- The `apply` job is a blocking manual action. It consumes the saved binary plan
  from that pipeline, never generates another plan, and checks its target, backend,
  commit, project, pipeline, Azure subscription/tenant, checksum, and one-hour age.
- Plan/apply jobs use a resource group per target, plus OpenTofu's backend locking.
  A state change after planning can invalidate the saved plan; start a new pipeline
  instead of bypassing that check.

No destroy job is provided. Bootstrap state storage and cloud trust must exist
before deployment jobs can use them.

## 1. Prepare the registered runner

Install **OpenTofu 1.12.5**, **Python 3.9+**, Git, and CA certificates on the runner
host. Ensure `tofu` and `python3` are on PATH for the GitLab Runner service user.
Run as that user:

```sh
tofu version
python3 --version
```

The runner needs outbound access to GitLab, provider registries/download hosts,
Azure identity/management/Blob endpoints, and AWS STS/API endpoints for recordings.
It does not need private MySQL, Redis, or Key Vault data-plane connectivity for
these infrastructure jobs. Secret population would require separate connectivity.

Jobs have no runner tags by default. Enable **Run untagged jobs** on the registered
runner, or add its actual tags under `default:` in `.gitlab-ci.yml`. No new runner
registration is required.

Use a project-dedicated shell runner without persistent cloud credentials on its
host. Shell jobs share the service user's host access. Untrusted external merge
requests should run on a separate isolated validation runner. If this runner is
marked protected, it will not service ordinary unprotected branch jobs; provide
another runner for those validations or choose an appropriate trusted-branch policy.

The YAML uses GitLab ID tokens and `artifacts:access: developer`; use GitLab 16.11+
with a compatible runner. Validate it with your instance's **Pipeline editor >
Validate** before the first run, since instance-level policies may differ.

## 2. Bootstrap state once

Follow [deployment.md](deployment.md#2-bootstrap-state-storage) to create state
storage and migrate its initial local state. Bootstrap is validated by CI but is
not applied in CI: its first run cannot depend on the backend it is creating.

Grant the CI Azure identity Storage Blob Data Contributor on the relevant state
container/account, in addition to the resource-management permissions needed by
the selected target. Creating the foundation resource group requires appropriately
scoped subscription permissions. Application deployment also creates role
assignments, so Contributor alone is insufficient for that target. Prefer a scoped
custom/role-assignment administration role rather than broad subscription Owner.

Provider registration must be permitted or performed in advance according to your
subscription policy. State access is needed for both planning and applying.

## 3. Configure cloud authentication

OIDC is the default; each job receives fresh tokens.

**Azure federation**

Create an Entra application/service principal (or an appropriate managed identity
with federation) and configure its federated credential:

- Issuer: the exact GitLab instance URL, without an extra trailing slash.
- Audience: `api://AzureADTokenExchange`, matching this pipeline.
- Subject: `project_path:<group>/<project>:ref_type:branch:ref:<default-branch>`.

Scope the trust to this project and branch. The helper supplies `ARM_OIDC_TOKEN`
to OpenTofu/AzureRM directly; Azure CLI login is not needed on the runner.

For self-managed GitLab, Azure must be able to retrieve GitLab's OIDC discovery and
signing keys. If that is not possible, set `AZURE_AUTH_MODE=client_secret` and add a
protected, masked `ARM_CLIENT_SECRET` instead. The other ARM identity variables are
still required. [GitLab's Azure federation guide](https://docs.gitlab.com/ci/cloud_services/azure/)
describes the issuer, subject, audience, and reachability requirements.

**AWS federation, only for recordings**

Configure a GitLab IAM OIDC provider with audience `sts.amazonaws.com`, and an IAM
role whose trust allows `sts:AssumeRoleWithWebIdentity` only for this project's
default-branch subject. Grant that role the S3/IAM permissions required by
`modules/aws/recordings`, including creating the scoped recordings access policy.
The helper writes the job token to a temporary file used by the AWS provider.

The AWS deployment role is a CI identity; it is distinct from application writer
roles passed in `TF_VAR_writer_role_names`. Recordings also needs the Azure identity
because its state is stored in Azure Blob.

If federation is unavailable, `AWS_AUTH_MODE=environment` uses protected, masked
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and, for temporary credentials,
`AWS_SESSION_TOKEN`. The pipeline does not create access keys.
See [GitLab's AWS federation guide](https://docs.gitlab.com/ci/cloud_services/aws/).

## 4. Add project CI/CD variables

Under **Settings > CI/CD > Variables**, add the values below. Protect deployment
variables and scope them to the relevant target environments rather than `*`.
The environment name is the target ID. Use the same scope for plan and apply.
Mark secrets masked/hidden where supported, disable variable expansion for secrets,
and do not use File-type variables for `TF_VAR_*` values.

| Variable | Used by | Value |
| --- | --- | --- |
| `ARM_CLIENT_ID` | Every deployment | Azure CI identity client ID |
| `ARM_TENANT_ID` | Every deployment | Azure tenant ID |
| `ARM_SUBSCRIPTION_ID` | Every deployment | Intended Azure subscription |
| `STATE_RESOURCE_GROUP` | Every deployment | Bootstrap resource group |
| `STATE_STORAGE_ACCOUNT` | Every deployment | Bootstrap storage account |
| `STATE_CONTAINER` | Every deployment | State container, initially `tfstate` |
| `TF_VAR_key_vault_name` | Azure data | Globally unique Key Vault name |
| `TF_VAR_mysql_password` | Azure data | MySQL administrator secret |
| `TF_VAR_ssh_public_key` | Azure application | Full OpenSSH public key |
| `TF_VAR_ubuntu_image_version` | Azure application | Exact numeric Marketplace image version |
| `TF_VAR_admin_cidrs` | Azure application | JSON list, e.g. `["<your-public-ip>/32"]`; defaults to `[]` |
| `AWS_ROLE_ARN` | AWS recordings, OIDC | CI deployment role ARN |
| `TF_VAR_aws_account_id` | AWS recordings | Expected 12-digit account ID |
| `TF_VAR_bucket_name` | AWS recordings | Globally unique recordings bucket name |
| `TF_VAR_writer_role_names` | AWS recordings, optional | JSON list of existing trusted application roles; defaults to `[]` |

Common Azure variables can have scope `azure-aira-dev-*`; also supply the appropriate
Azure/backend values to `aws-aira-dev-recordings`. Secrets should have exact target
scopes. Do not set a global `TF_VAR_state_backend`: the helper derives it from
the backend variables. AWS region, deployment, and environment are derived from
the target path to prevent metadata drift.

Keep default-branch merges restricted. Where supported by your GitLab tier,
protect the target environments and restrict **Allowed to deploy** to the intended
operators. Restrict who can supply pipeline variables; do not override predefined
`CI_*` variables or runner-local `TF_CLI_ARGS*` flags.

## 5. Run the first deployment

Push the reviewed files and merge to your protected default branch. Validation
runs automatically. Then use **Build > Pipelines > New pipeline / Run pipeline**:

1. Select the default branch.
2. Set `RUN_DEPLOYMENT=true`.
3. Choose `DEPLOY_TARGET` from the table below.
4. Wait for validation/tests and the plan to pass.
5. Review the plan job log, then run its manual `apply` within one hour.

| Target | Prerequisites |
| --- | --- |
| `azure-aira-dev-foundation` | State bootstrap and Azure CI trust |
| `azure-aira-dev-data` | Foundation applied |
| `azure-aira-dev-application` | Foundation and data applied |
| `aws-aira-dev-recordings` | State bootstrap, Azure CI trust, AWS CI trust |

Use a separate pipeline per target. This supports the first deployment, when data
and application cannot plan until dependency states exist. It also allows small
changes without applying unrelated components. Complete prerequisite changes
before planning dependents; per-target serialization does not lock an entire
multi-component installation.

If an apply fails or the artifact expires, start a new pipeline and review a fresh
plan against the actual state. Do not retry a partially applied saved plan blindly.

## Plan artifacts and state

Only `.ci-plan/deployment.tfplan` and its metadata are published. No state files,
provider/backend working directories, token files, or variable files are cached or
uploaded. OpenTofu plans can contain secrets even when console output redacts them.
Artifacts are restricted to Developer and higher roles, expire after one hour,
and the helper independently enforces the one-hour apply deadline.

Disable **Keep artifacts from most recent successful jobs** if strict timed removal
is required; GitLab retention settings can otherwise retain artifacts beyond
`expire_in`. For GitLab 18.4+, change artifact access to `maintainer` if only
Maintainers should download plans. Also restrict CI/CD visibility to project
members and configure job-token access for this private project.
[GitLab artifact documentation](https://docs.gitlab.com/ci/jobs/job_artifacts/)
explains artifact access and retention.

Jobs use isolated temporary OpenTofu data directories and fresh provider
initialization with `-lockfile=readonly`. Plan and apply run the same pinned CLI
and commit. Both still require working cloud permissions; local tests cannot
verify your GitLab instance, runner, federation, quota, or actual deployment.

## Adding installations and environments

Create new thin live roots with committed lock files and update their shared
deployment settings. Add an ID, root path, and prerequisite IDs in `ci/targets.json`.
Use exactly one target ID per state. No new job definitions are necessary.

Add environment-scoped GitLab variables and matching cloud permissions for the
new target. Give separate installations/environments separate backend containers
or accounts when they need permission isolation. State keys alone do not isolate
access. The helper verifies Azure deployment metadata matches the target path.

The CI helper and its unit tests use Python's standard library. Run locally:

```sh
python3 -m unittest discover -s ci/tests -v
python3 ci/run.py validate
python3 ci/run.py test
```
