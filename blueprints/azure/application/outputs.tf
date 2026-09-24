output "machines" {
  value = { for name, machine in module.machine : name => {
    id           = machine.id
    public_ip    = machine.public_ip
    private_ip   = machine.private_ip
    principal_id = machine.principal_id
  } }
}
