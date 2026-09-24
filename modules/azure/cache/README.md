# cache

Creates Azure Managed Redis with HA disabled, TLS, and a private endpoint/DNS. Public access is disabled. Access keys are retained in protected provider state but not exported by this module. Cache persistence is not enabled.

See `variables.tf` for typed inputs and `outputs.tf` for the public interface. Use this module through the live roots and blueprints described in the repository README.
