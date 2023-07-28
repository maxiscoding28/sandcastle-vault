#   __________________________________   _________________________  _________
#  /   _____/\_   _____/\______   \   \ /   /\_   _____/\______   \/   _____/
#  \_____  \  |    __)_  |       _/\   Y   /  |    __)_  |       _/\_____  \ 
#  /        \ |        \ |    |   \ \     /   |        \ |    |   \/        \
# /_______  //_______  / |____|_  /  \___/   /_______  / |____|_  /_______  /
#         \/         \/         \/                   \/         \/        \/ 
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
variable "primary_cluster_server_count" {
  type    = number
  default = 0
}
variable "secondary_cluster_server_count" {
  type    = number
  default = 0
}
variable "vault_license" {
  type = string
}
variable "kms_key_arn" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_id_a" {
  type = string
}
variable "subnet_id_b" {
  type = string
}
variable "security_group_id" {
  type = string
}
variable "iam_instance_profile_name" {
  type = string
}
# You will need to create this through AWS console or CLI
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html
variable "ssh_key_name" {
  type = string
}

resource "aws_launch_template" "sandcastle_vault_primary" {
  name_prefix            = "sandcastle_vault_primary"
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
    region        = var.region,
    vault_version = var.vault_version
    vault_license = var.vault_license
    kms_key_arn   = var.kms_key_arn
    cluster       = "primary"
  }))
}

resource "aws_launch_template" "sandcastle_vault_secondary" {
  name_prefix            = "sandcastle_vault_secondary"
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
    region        = var.region,
    vault_version = var.vault_version
    vault_license = var.vault_license
    kms_key_arn   = var.kms_key_arn
    cluster       = "secondary"
  }))
}

resource "aws_autoscaling_group" "sandcastle_vault_primary" {
  name                = "sandcastle_vault_primary"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.primary_cluster_server_count
  max_size            = 5
  min_size            = 0

  launch_template {
    id      = aws_launch_template.sandcastle_vault_primary.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sandcastle_vault_primary"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "join"
    value               = "sandcastle_vault_primary"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "sandcastle_vault_secondary" {
  name                = "sandcastle_vault_secondary"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.secondary_cluster_server_count
  max_size            = 5
  min_size            = 0

  launch_template {
    id      = aws_launch_template.sandcastle_vault_secondary.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sandcastle_vault_secondary"
    propagate_at_launch = true
  }

  tag {
    key                 = "join"
    value               = "sandcastle_vault_secondary"
    propagate_at_launch = true
  }
}