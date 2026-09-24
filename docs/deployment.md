# Deploying Aira infrastructure

Run commands from the repository root unless a step says otherwise. Use OpenTofu
1.11 or newer within major version 1; local verification uses 1.12.5. AzureRM is
constrained to 4.67.x. AWS is constrained to major version 6, with the exact version
selected in its committed lock file.

## 1. Authenticate and choose inputs

Use Azure CLI login or your organization's service-principal/workload identity
environment. Set `ARM_SUBSCRIPTION_ID` to the intended subscription.
No credentials belong in backend HCL or committed JSON.

The bootstrap principal needs resource creation and role-assignment permissions.
It is assigned Storage Blob Data Contributor on the created account. Give later
deployment identities the state access and Azure permissions their roots require;
application deployment creates Key Vault reader role assignments and therefore
also needs permission to assign those roles.

Check VM/MySQL/Managed Redis capacity and quota in Central India before applying.
Use Azure CLI to select an exact Ubuntu image version, then put the selected version
into application inputs:

```powershell
az vm image list --location centralindia --publisher Canonical --offer ubuntu-24_04-lts --sku server --all --query "[].version" -o tsv
```

The application root rejects `latest`. Check the shared CIDRs against any connected
networks. Leave `admin_cidrs = []` to disable SSH, or supply actual administrative
IPv4 CIDRs. Neither the example CIDRs from tests nor the ZIP's administrator address
is an operational default.

## 2. Bootstrap state storage

Copy `bootstrap/azure/inputs.example.tfvars` to
`bootstrap/azure/terraform.tfvars` and replace the storage name placeholder.

```powershell
tofu -chdir=bootstrap/azure init
tofu -chdir=bootstrap/azure plan -out=bootstrap.tfplan
tofu -chdir=bootstrap/azure apply bootstrap.tfplan
tofu -chdir=bootstrap/azure output backend
```

Review each saved plan before applying it. Bootstrap starts with local state,
because the backend does not exist yet. Its storage account has a destruction
guard and uses Entra authentication, HTTPS, disabled shared keys, blob versioning,
and retention. Role assignments may need time to propagate before container creation;
if propagation causes a 403, rerun the bootstrap plan after access is effective.

Once storage exists, create `bootstrap/azure/backend.tf`:

```hcl
terraform {
  backend "azurerm" {}
}
```

Create `bootstrap/azure/backend.hcl` using the output values, plus the unique
key `bootstrap/azure/state.tfstate`. Then migrate the bootstrap state:

```powershell
tofu -chdir=bootstrap/azure init -migrate-state -backend-config=backend.hcl
```

Verify that the remote state is present before removing any local state backup.
Never commit local state. The backend's default network endpoint is public but
requires Entra authorization; additional private networking for state is a future
operating choice requiring a suitably connected runner.

## 3. Configure live roots

For each root, copy `backend.example.hcl` to `backend.hcl` and fill in the actual
backend coordinates. Preserve a unique key for each component. For data and
application, copy `inputs.example.tfvars` to `terraform.tfvars` and fill in the values.
Set `state_backend` to the same backend used for that installation's dependencies.

The initial keys are:

```text
azure/aira/dev/centralindia/foundation.tfstate
azure/aira/dev/centralindia/data.tfstate
azure/aira/dev/centralindia/application.tfstate
aws/aira/dev/ap-south-1/recordings.tfstate
```

Edit shared sizes/names/network settings in
`live/azure/aira/dev/centralindia/deployment.json`. Paths, metadata, and backend keys
must agree when replicating an installation. MySQL and Redis names are derived in
`modules/deployment`; optional `mysql.name`, `redis.name`, `resource_group_name`,
and per-machine `name` entries in deployment JSON override the defaults. Use a
unique installation identifier for each independent installation.
Key Vault uses an explicitly supplied unique name because its naming length limit
is shorter.

## 4. Deploy foundation, data, then application

Use this sequence separately for each component directory:

```powershell
tofu -chdir=live/azure/aira/dev/centralindia/foundation init -backend-config=backend.hcl
tofu -chdir=live/azure/aira/dev/centralindia/foundation plan -out=deployment.tfplan
tofu -chdir=live/azure/aira/dev/centralindia/foundation apply deployment.tfplan
```

Repeat with `data`, then `application`. After local validation with
`init -backend=false`, normal initialization is still required for real operations.

For the data plan, populate `TF_VAR_mysql_password` from your existing secret manager
or secure local input; never type a literal secret into a committed file. OpenTofu's
sensitive flag hides normal display, but does not remove secrets from state/plans.
Remove the environment variable from the shell after use.

For application inputs, supply the exact image version and SSH public key.
Outputs provide both VM IPs and managed-identity principal IDs. No applications
will answer on ports 80/443 until separately installed and configured.

Key Vault is private and initially empty. Populate secrets later from a host with
VNet connectivity, using an identity with Key Vault Secrets Officer or equivalent
scoped permissions. The VM identities have read access only. Secret population,
application credentials, TLS certificates, and runtime configuration are outside
this infrastructure deployment.

## 5. Deploy recordings

The AWS root also uses Azure Blob state, so both Azure backend authentication and
AWS provider authentication are needed. Use AWS SSO, an assumed role, or the
organization's supported credential chain. No credentials are passed in tfvars.

Copy the recordings input example to `terraform.tfvars`; select a unique bucket
name and the expected AWS account ID. `allowed_account_ids` guards against deploying
into another AWS account. The default AWS region is Mumbai (`ap-south-1`), chosen
for proximity to the Azure reference region, not supplied by the ZIP.

Initialize, plan, and apply the recordings root as above. By default,
`writer_role_names` is empty: a scoped policy is created but no runtime identity
receives it. Supply existing role names only after their trust relationships are
configured. This root deliberately does not invent cross-cloud authentication or
create IAM user access keys.

## Validation and subsequent changes

Run `scripts/validate.ps1` before reviewing real plans. Mocked tests make no cloud
calls. Real deployment verification must include SSH from allowed sources, private
DNS resolution from the VMs, MySQL/Redis TLS connectivity, and backup recovery.
Quota, SKU availability, global name uniqueness, RBAC propagation, and network
reachability cannot be established by local validation.

For a new deployment, change the installation identifier, backend keys/coordinates,
and globally unique names. For a new environment, change the environment and allocate
its own state/access boundary. Nonoverlapping CIDRs are required if networks will be
connected. Do not change the metadata of an already deployed root merely to create
another installation; that would plan changes against the existing state.

Apply foundation before data/application, and destroy dependents before their
foundation when deliberately decommissioning. S3 refuses forced deletion of a
nonempty bucket. Vault purge protection delays permanent deletion. Bootstrap
storage has a destruction guard. Database restore and state recovery should be
tested in a separate environment.

## Provider references

- [AzureRM Managed Redis](https://registry.terraform.io/providers/hashicorp/azurerm/4.67.0/docs/resources/managed_redis)
- [MySQL private networking](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-networking-vnet)
- [Managed Redis private endpoints](https://learn.microsoft.com/en-us/azure/redis/private-link)
