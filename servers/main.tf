#   __________________________________   _________________________  _________
#  /   _____/\_   _____/\______   \   \ /   /\_   _____/\______   \/   _____/
#  \_____  \  |    __)_  |       _/\   Y   /  |    __)_  |       _/\_____  \ 
#  /        \ |        \ |    |   \ \     /   |        \ |    |   \/        \
# /_______  //_______  / |____|_  /  \___/   /_______  / |____|_  /_______  /
#         \/         \/         \/                   \/         \/        \/ 
resource "aws_launch_template" "sandcastle_vault_primary" {
  name_prefix            = "sandcastle_vault_primary"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = var.storage_backend == "consul" ? [var.vault_security_group_id, var.consul_security_group_id] : [var.vault_security_group_id]
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }
  metadata_options {
    http_tokens = "optional"
  }
  user_data = base64encode(templatefile("./scripts/bootstrap-vault.sh", {
    cluster         = "primary"
    region          = var.region
    vault_version   = var.vault_version
    vault_license   = var.vault_license
    kms_key_arn     = var.kms_key_arn
    storage_backend = var.storage_backend
    consul_license  = var.consul_license
    consul_version  = var.consul_version
  }))
}
resource "aws_launch_template" "sandcastle_vault_secondary" {
  count                  = var.replication_mode ? 1 : 0
  name_prefix            = "sandcastle_vault_secondary"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = var.storage_backend == "consul" ? [var.vault_security_group_id, var.consul_security_group_id] : [var.vault_security_group_id]
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }
  metadata_options {
    http_tokens = "optional"
  }
  user_data = base64encode(templatefile("./scripts/bootstrap-vault.sh", {
    cluster         = "secondary"
    region          = var.region
    vault_version   = var.vault_version
    vault_license   = var.vault_license
    kms_key_arn     = var.kms_key_arn
    storage_backend = var.storage_backend
    consul_license  = var.consul_license
    consul_version  = var.consul_version
  }))
}
resource "aws_launch_template" "sandcastle_vault_consul_storage_primary" {
  lifecycle {
    precondition {
      condition     = (var.primary_cluster_consul_storage_server_count > 0 && var.primary_cluster_server_count > 0) || (var.primary_cluster_consul_storage_server_count == 0 && var.primary_cluster_server_count == 0)
      error_message = "Nodes for the primary vault cluster are being created with storage type: consul but no consul nodes are being created. \n\t- To scale up: set variable 'primary_cluster_consul_storage_server_count' to a value greater than 0.\n\t- To scale down: set variable 'primary_cluster_server_count' to 0"
    }
  }
  name_prefix   = "sandcastle_vault_consul_storage_primary"
  count         = var.storage_backend == "consul" ? 1 : 0
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name
  vpc_security_group_ids = [
    var.vault_security_group_id,
    var.consul_security_group_id
  ]
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }
  metadata_options {
    http_tokens = "optional"
  }
  user_data = base64encode(templatefile("./scripts/bootstrap-consul.sh", {
    cluster        = "primary"
    region         = var.region
    consul_license = var.consul_license
    consul_version = var.consul_version,
    servers_count  = var.primary_cluster_consul_storage_server_count
  }))
}
resource "aws_launch_template" "sandcastle_vault_consul_storage_secondary" {
  lifecycle {
    precondition {
      condition     = (var.secondary_cluster_consul_storage_server_count > 0 && var.secondary_cluster_server_count > 0 && var.replication_mode) || (var.secondary_cluster_consul_storage_server_count == 0 && var.secondary_cluster_server_count == 0 && var.replication_mode)
      error_message = "Nodes for the secondary vault cluster are being created with storage type: consul but no consul nodes are being created. \n\t- To scale up: set variable 'secondary_cluster_consul_storage_server_count' to a value greater than 0.\n\t- To scale down: set variable 'secondary_cluster_server_count' to 0"
    }
  }
  name_prefix   = "sandcastle_vault_consul_storage_secondary"
  count         = var.storage_backend == "consul" && var.replication_mode ? 1 : 0
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name
  vpc_security_group_ids = [
    var.vault_security_group_id,
    var.consul_security_group_id
  ]
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }
  metadata_options {
    http_tokens = "optional"
  }
  user_data = base64encode(templatefile("./scripts/bootstrap-consul.sh", {
    cluster        = "secondary"
    region         = var.region
    consul_license = var.consul_license
    consul_version = var.consul_version,
    servers_count  = var.secondary_cluster_consul_storage_server_count

  }))
}
resource "aws_autoscaling_group" "sandcastle_vault_primary" {
  name                = "sandcastle_vault_primary"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.primary_cluster_server_count
  max_size            = 5
  min_size            = 0
  target_group_arns   = [var.sandcastle_vault_primary_target_group_id]
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
  count               = var.replication_mode ? 1 : 0
  name                = "sandcastle_vault_secondary"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.secondary_cluster_server_count
  max_size            = 5
  min_size            = 0
  target_group_arns   = [var.sandcastle_vault_secondary_target_group_id]
  launch_template {
    id      = aws_launch_template.sandcastle_vault_secondary[0].id
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
resource "aws_autoscaling_group" "sandcastle_vault_consul_storage_primary" {
  count               = var.storage_backend == "consul" ? 1 : 0
  name                = "sandcastle_vault_consul_storage_primary"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.primary_cluster_consul_storage_server_count
  max_size            = 5
  min_size            = 0
  launch_template {
    id      = aws_launch_template.sandcastle_vault_consul_storage_primary[0].id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "sandcastle_vault_consul_storage_primary"
    propagate_at_launch = true
  }
  tag {
    key                 = "join"
    value               = "sandcastle_vault_consul_storage_primary"
    propagate_at_launch = true
  }
}
resource "aws_autoscaling_group" "sandcastle_vault_consul_storage_secondary" {
  count               = var.storage_backend == "consul" && var.replication_mode ? 1 : 0
  name                = "sandcastle_vault_consul_storage_secondary"
  vpc_zone_identifier = [var.subnet_id_a, var.subnet_id_b]
  desired_capacity    = var.secondary_cluster_consul_storage_server_count
  max_size            = 5
  min_size            = 0
  launch_template {
    id      = aws_launch_template.sandcastle_vault_consul_storage_secondary[0].id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "sandcastle_vault_consul_storage_secondary"
    propagate_at_launch = true
  }
  tag {
    key                 = "join"
    value               = "sandcastle_vault_consul_storage_secondary"
    propagate_at_launch = true
  }
}