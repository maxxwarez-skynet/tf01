# Aira infrastructure

Reusable OpenTofu infrastructure for independent installations and environments.
The first configuration is `aira/dev` in Azure Central India. AWS currently hosts
only the recordings bucket; AWS application hosting is a future implementation.

## Initial infrastructure

| Component | Configuration |
| --- | --- |
| Frontend | One Ubuntu 24.04 LTS VM, `Standard_B2ms`, zone 1 |
| AI | One Ubuntu 24.04 LTS VM, `Standard_B2ms`, zone 1 |
| Ingress | Separate static public IP per VM; TCP 80/443 on both |
| Administration | SSH public key; TCP 22 only from supplied IPv4 CIDRs |
| MySQL | `B_Standard_B1ms`, version identifier `8.0.21`, 20 GB, zone 1, no HA |
| MySQL recovery | Seven days of point-in-time recovery, no geo-redundant backup |
| Redis | Azure Managed Redis `Balanced_B0`, TLS, private endpoint, HA disabled |
| Secrets | Private Azure Key Vault; VM managed identities have secrets-read access |
| Recordings | Private, encrypted, versioned S3 bucket in `ap-south-1` by default |

The ZIP was used only as a reference for naming, regions, sizes, and SKUs.
No credentials, CI runner configuration, or existing state layout were imported.
Names are derived from installation and environment, for example
`rg-aira-dev`, `aira-dev-fe-01`, and `aira-dev-agent-01`.

This repository deploys infrastructure only. It does not install application
software, Docker, GitLab runners, reverse proxies, or TLS certificates. Opening
80/443 does not create a listener or enable HTTPS. Traffic Manager is omitted.
VMs and MySQL use the selected zone; Managed Redis does not expose zone placement
in this module/provider. There is no application failover.

## Repository structure

```text
bootstrap/azure/             Initial remote state storage
modules/deployment/          Shared settings and naming
modules/azure/               Network, compute, MySQL, cache, secrets
modules/aws/recordings/      S3 and a scoped recordings access policy
blueprints/azure/             Foundation, data, application compositions
live/azure/aira/dev/centralindia/
  deployment.json            Shared non-secret settings
  foundation/                Resource group and network state
  data/                      MySQL, Redis, Key Vault state
  application/               VMs, public IPs, NSGs, vault-read role assignments
live/aws/aira/dev/ap-south-1/recordings/
scripts/validate.ps1          Local validation and mocked tests
.gitlab-ci.yml               Linux shell-runner pipeline
ci/targets.json              Deployment targets and prerequisites
ci/run.py                    CI validation, planning, and saved-plan application
docs/deployment.md           Bootstrap and deployment runbook
```

Each live root is independently planned and applied. Azure application deployment
depends on foundation and data outputs. AWS recordings can be deployed independently
once state storage exists. Module inputs and outputs are defined in each module's
`variables.tf` and `outputs.tf`.

All initial states, including the AWS recordings state, use the Azure Blob backend
created by bootstrap. This avoids a second bootstrap solely for one S3 bucket.
This is an explicit operating choice, not a requirement for future AWS installations.

## GitLab CI/CD

The Linux shell-runner pipeline runs validation and mocked tests on branch/MR
pipelines. Manually started deployment pipelines on the protected default branch
plan one selected component, then offer a manual apply of that exact saved plan.
See [GitLab setup and required CI variables](docs/gitlab-ci.md). Targets are listed
in `ci/targets.json`; additional installations reuse the same jobs.

## Start here

Follow [the deployment runbook](docs/deployment.md). Before any real plan, supply:

- Azure subscription/authentication and globally unique backend storage name.
- A globally unique Key Vault name; override MySQL/Redis naming if needed.
- An SSH public key and the actual administrative CIDRs.
- An exact Ubuntu Marketplace image version.
- A MySQL administrator password from a secret manager or secure input.
- AWS account/authentication and globally unique bucket name for recordings.

No cloud resources have been provisioned. Availability of reference SKUs in the
selected subscription, region, and zone must be checked before deployment.

Validate locally with OpenTofu (tested with 1.12.5):

```powershell
./scripts/validate.ps1
```

The script initializes with the backend disabled, validates the five roots, and
runs mocked tests for ingress, private/no-HA data services, and S3 protections.
Provider downloads require internet access. These checks do not authenticate to
Azure/AWS and do not create resources. They do not establish regional capacity,
subscription quota, actual connectivity, or restore success.

Provider versions are constrained and each deployment root has a dependency lock
file. Commit those lock files. OpenTofu registry addresses are explicit so the CLI and read-only CI lock checks
resolve the same provider sources.

## Replication and expansion

A deployment is an independent installation; an environment is a lifecycle stage
inside it. Root identity is:

```text
<cloud>/<deployment>/<environment>/<region>/<component>
```

To create another installation or environment, copy the thin live roots, update
`deployment.json`, backend coordinates/keys, and local input values, then review
each plan. Reuse the same modules and blueprints. Shared settings contain no secrets.
All machines are keyed in a map so additional instances can be added without
renumbering existing resource addresses.

State keys separate ownership, not permissions. Use separate backend containers
or accounts and deployment credentials for installations/environments that require
access isolation. Application's remote-state reader can access the complete data
state, including credentials; grant that identity accordingly. Do not use CLI
workspace names as an access-control boundary.

Future HA, multi-zone placement, and AWS application blueprints require deliberate
implementation and migration planning. Changes to placement, networking, or data
services may replace resources. Keep architecture shared within each cloud and
implement cloud-specific capabilities in their own modules.

## Secret and recovery boundaries

MySQL credentials are supplied externally and may be persisted in state and saved
plans. Redis access keys are also in provider-managed state. Protect both artifacts.
The Key Vault is created empty; secret population/rotation and application retrieval
are separate operational steps. Public vault access is disabled, so secret operations
need VNet connectivity and an appropriately authorized identity.

Recordings access is a scoped IAM policy, optionally attached to existing AWS roles.
No long-lived AWS access keys or Azure-to-AWS trust relationship are created.
Selecting the application's cross-cloud authentication method is a later integration
step; provisioning a bucket does not grant the Azure VMs access to it.

MySQL backups and S3 versioning provide basic recovery features, not a tested disaster
recovery solution. Redis is treated as disposable cache, and bare VMs are rebuildable;
Redis persistence and VM backup are not included. State storage uses local redundancy,
blob versioning, and 30-day deletion retention. Test recovery separately before
production use.
