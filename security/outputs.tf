output "iam_instance_profile_name" {
  value = aws_iam_instance_profile.sandcastle_vault.name
}
output "vault_security_group_id" {
  value = aws_security_group.sandcastle_vault.id
}
output "consul_security_group_id" {
  value = var.storage_backend == "consul" ? aws_security_group.sandcastle_vault_on_consul[0].id : ""
}
output "load_balancer_security_group_id" {
  value = var.load_balancer_mode != "none" ? aws_security_group.sandcastle_vault_from_local_to_loadbalancer[0].id : ""
}