output "mysql_fqdn" { value = module.mysql.fqdn }
output "redis_hostname" { value = module.cache.hostname }
output "redis_port" { value = module.cache.port }
output "key_vault_id" { value = module.secrets.id }
output "key_vault_uri" { value = module.secrets.uri }
