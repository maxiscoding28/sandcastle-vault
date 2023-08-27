variable "region" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "vault_version" {
  type = string
}
variable "consul_version" {
  type = string
}
variable "ami_id" {
  type = string
}
variable "primary_cluster_server_count" {
  default = 1
}
variable "secondary_cluster_server_count" {
  default = 1
}
variable "primary_cluster_consul_storage_server_count" {
  type = number
}
variable "secondary_cluster_consul_storage_server_count" {
  type = number
}
variable "storage_backend" {
  type = string
}
variable "replication_mode" {
  type = bool
}
variable "consul_license" {
  type = string
}
variable "load_balancer_mode" {
  type = string
}
variable "vault_license" {
  type = string
}
variable "aws_account_id" {
  type = string
}
variable "aws_role_arn" {
  type = string
}
variable "ssh_key_name" {
  type = string
}
variable "vault_security_group_id" {
  type = string
}
variable "consul_security_group_id" {
  type = string
}
variable "iam_instance_profile_name" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "subnet_id_a" {
  type = string
}
variable "subnet_id_b" {
  type = string
}
variable "sandcastle_vault_primary_target_group_id" {
  type = string
}
variable "sandcastle_vault_secondary_target_group_id" {
  type = string
}
