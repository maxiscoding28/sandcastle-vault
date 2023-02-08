#   _________   _____    _______  ________  _________     _____    ____________________.____     ___________ _________
#  /   _____/  /  _  \   \      \ \______ \ \_   ___ \   /  _  \  /   _____/\__    ___/|    |    \_   _____//   _____/
#  \_____  \  /  /_\  \  /   |   \ |    |  \/    \  \/  /  /_\  \ \_____  \   |    |   |    |     |    __)_ \_____  \ 
#  /        \/    |    \/    |    \|    `   \     \____/    |    \/        \  |    |   |    |___  |        \/        \
# /_______  /\____|__  /\____|__  /_______  /\______  /\____|__  /_______  /  |____|   |_______ \/_______  /_______  /
#         \/         \/         \/        \/        \/         \/        \/                    \/        \/        \/ 
module "network" {
  source = "./network"
  region = var.region
}
module "security" {
  source          = "./security"
  aws_account_id  = var.aws_account_id
  aws_role_arn    = var.aws_role_arn
  local_ip        = var.local_ip
  storage_backend = var.storage_backend
  vpc_id          = module.network.vpc_id
  kms_key_arn     = module.network.kms_key_arn
  load_balancer_mode = var.load_balancer_mode
}
module "load_balancer" {
  source     = "./loadbalancer"
  mode       = var.load_balancer_mode
  vpc_id     = module.network.vpc_id
  subnet_ids = [module.network.subnet_id_a, module.network.subnet_id_b]
  security_group_id = module.security.load_balancer_security_group_id

}
resource "aws_launch_template" "sandcastle_vault_primary" {
  name_prefix            = "sandcastle_vault_primary"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [
    module.security.vault_security_group_id,
    module.security.consul_security_group_id
  ]
  iam_instance_profile {
    name = module.security.iam_instance_profile_name
  }
  metadata_options {
    http_tokens = "optional"
  }
  user_data = base64encode(templatefile("./scripts/bootstrap-vault.sh", {
    cluster         = "primary"
    region          = var.region
    vault_version   = var.vault_version
    vault_license   = var.vault_license
    kms_key_arn     = module.network.kms_key_arn
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
  vpc_security_group_ids = [
    module.security.vault_security_group_id,
    module.security.consul_security_group_id
  ]
  iam_instance_profile {
    name = module.security.iam_instance_profile_name
  }
  metadata_options {
    http_tokens = "optional"
  }
  user_data = base64encode(templatefile("./scripts/bootstrap-vault.sh", {
    cluster         = "secondary"
    region          = var.region
    vault_version   = var.vault_version
    vault_license   = var.vault_license
    kms_key_arn     = module.network.kms_key_arn
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
  name_prefix            = "sandcastle_vault_consul_storage_primary"
  count                  = var.storage_backend == "consul" ? 1 : 0
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [
    module.security.vault_security_group_id,
    module.security.consul_security_group_id
  ]
  iam_instance_profile {
    name = module.security.iam_instance_profile_name
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
  name_prefix            = "sandcastle_vault_consul_storage_secondary"
  count                  = var.storage_backend == "consul" && var.replication_mode ? 1 : 0
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [
    module.security.vault_security_group_id,
    module.security.consul_security_group_id
  ]
  iam_instance_profile {
    name = module.security.iam_instance_profile_name
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
  vpc_zone_identifier = [module.network.subnet_id_a, module.network.subnet_id_b]
  desired_capacity    = var.primary_cluster_server_count
  max_size            = 5
  min_size            = 0
  target_group_arns   = [var.load_balancer_mode == "alb" ? module.load_balancer.sandcastle_vault_primary_target_group_id : ""]
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
  vpc_zone_identifier = [module.network.subnet_id_a, module.network.subnet_id_b]
  desired_capacity    = var.secondary_cluster_server_count
  max_size            = 5
  min_size            = 0
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
  vpc_zone_identifier = [module.network.subnet_id_a, module.network.subnet_id_b]
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
  vpc_zone_identifier = [module.network.subnet_id_a, module.network.subnet_id_b]
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