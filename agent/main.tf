variable "region" {
  type    = string
  default = "us-west-2"
}
variable "instance_type" {
  type    = string
  default = "t2.micro"
}
variable "vault_version" {
  type    = string
  default = "1.14.0+ent"
}
variable "ami_id" {
  type    = string
  default = "ami-0ab193018f3e9351b"
}
variable "vault_license" {
  type = string
}
variable "agent_count" {
  type = string
  default = 0
}
variable "ssh_key_name" {
  type = string
}
variable "security_group_id" {
  type = string
}
variable "iam_instance_profile_name" {
  type = string
}
variable "subnet_id_a" {
  type = string
}
variable "subnet_id_b" {
  type = string
}

resource "aws_launch_template" "sandcastle_vault_agent" {
  name_prefix            = "sandcastle_vault_agent"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [var.security_group_id]
  
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }
  
  metadata_options {
    http_tokens = "optional"
  }
  
  user_data = base64encode(templatefile("./startup.sh", {
    vault_version = var.vault_version
    vault_license = var.vault_license
  }))
}
resource "aws_autoscaling_group" "sandcastle_vault_agent" {
  name                = "sandcastle_vault_agent"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.agent_count
  max_size            = 5
  min_size            = 0

  launch_template {
    id      = aws_launch_template.sandcastle_vault_agent.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sandcastle_vault_agent"
    propagate_at_launch = true
  }
}