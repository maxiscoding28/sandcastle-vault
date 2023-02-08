variable "region" {
  type        = string
  description = "The AWS region in which to deploy the resources"
  default     = "us-west-2"
}
variable "instance_type" {
  type        = string
  description = "The EC2 instance size for the deploy Vault (and optionally Consul) servers"
  default     = "t2.micro"
}
variable "vault_version" {
  type        = string
  description = "The vault server version"
  default     = "1.14.1+ent"
}
variable "consul_version" {
  type        = string
  description = "The consul server version"
  default     = "1.16.0+ent"
}
variable "ami_id" {
  type        = string
  description = "AMI to use. Default is the Amazon Linux 2023 AMI - 64 bit (x86)"
  default     = "ami-002829755fa238bfa"
}
variable "primary_cluster_server_count" {
  description = "Number of nodes for the primary vault cluster"
  type        = number
  default     = 1
}
variable "secondary_cluster_server_count" {
  description = "Number of nodes for the secondary vault cluster"
  type        = number
  default     = 1
}
variable "primary_cluster_consul_storage_server_count" {
  type        = number
  description = "Number of nodes for the primary vault's consul storage cluster"
  default     = 0
}
variable "secondary_cluster_consul_storage_server_count" {
  type        = number
  description = "Number of nodes for the secondary vault's consul storage cluster"
  default     = 0
}
variable "storage_backend" {
  type        = string
  description = "The type of storage backend to use. Must be either 'raft' or 'consul"
  default     = "raft"
  validation {
    condition     = can(regex("^(raft|consul)$", var.storage_backend))
    error_message = "The value for storage_backend must be either 'raft' or 'consul'"
  }
}
variable "local_ip" {
  type        = string
  description = "The local IPv4 address"
  default     = "0.0.0.0/0"
}
variable "replication_mode" {
  type        = bool
  description = "Defines whether a secondary vault cluster should be created"
  default     = false
}
variable "consul_license" {
  type        = string
  description = "The consul enterprise license"
  default     = ""
}
variable "load_balancer_mode" {
  type        = string
  description = "The type of load balancer to create for the vault cluster"
  default     = "none"
  validation {
    condition     = can(regex("^(none|alb|nlb)$", var.load_balancer_mode))
    error_message = "The value for load_balancer_mode must be either 'none', 'alb' or 'nlb'"
  }
}
variable "vault_license" {
  type        = string
  description = "The vault enterprise license"
}
variable "aws_account_id" {
  type        = string
  description = "The AWS account ID for provisioning resources"
}
variable "aws_role_arn" {
  type        = string
  description = "The AWS role arn"
}
variable "ssh_key_name" {
  type        = string
  description = "The SSH key name for EC2 access"
}