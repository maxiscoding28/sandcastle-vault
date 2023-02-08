output "kms_key_arn" {
  value = aws_kms_key.sandcastle_vault.arn
}
output "vpc_id" {
  value = aws_vpc.sandcastle_vault.id
}
output "subnet_id_a" {
  value = aws_subnet.sandcastle_vault_a.id
}
output "subnet_id_b" {
  value = aws_subnet.sandcastle_vault_b.id
}