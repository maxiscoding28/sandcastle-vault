variable "mode" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_id" {
  type = string
}
variable "replication_mode" {
  type = bool
}