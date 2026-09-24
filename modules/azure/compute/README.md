# compute

Creates one bare Ubuntu VM with a static public IP, NIC, managed identity, and NIC-level NSG. Public application ports default to 80/443; SSH requires explicit IPv4 administrative CIDRs. Supply a pinned image and public SSH key.

See `variables.tf` for typed inputs and `outputs.tf` for the public interface. Use this module through the live roots and blueprints described in the repository README.
