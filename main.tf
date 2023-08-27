#                T~~
#                |
#               /"\
#       T~~     |'| T~~
#   T~~ |    T~ WWWW|
#   |  /"\   |  |  |/\T~~
#  /"\ WWW  /"\ |' |WW|
# WWWWW/\| /   \|'/\|/"\
# |   /__\/]WWW[\/__\WWWW
# |"  WWWW'|I_I|'WWWW'  |
# |   |' |/  -  \|' |'  |
# |'  |  |LI=H=LI|' |   |
# |   |' | |[_]| |  |'  |
# |   |  |_|###|_|  |   |
# '---'--'-/___\-'--'---'
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
  source             = "./security"
  aws_account_id     = var.aws_account_id
  aws_role_arn       = var.aws_role_arn
  local_ip           = var.local_ip
  storage_backend    = var.storage_backend
  vpc_id             = module.network.vpc_id
  kms_key_arn        = module.network.kms_key_arn
  load_balancer_mode = var.load_balancer_mode
}
module "servers" {
  source                                        = "./servers"
  region                                        = var.region
  instance_type                                 = var.instance_type
  vault_version                                 = var.vault_version
  consul_version                                = var.consul_version
  ami_id                                        = var.ami_id
  primary_cluster_server_count                  = var.primary_cluster_server_count
  secondary_cluster_server_count                = var.secondary_cluster_server_count
  primary_cluster_consul_storage_server_count   = var.primary_cluster_consul_storage_server_count
  secondary_cluster_consul_storage_server_count = var.secondary_cluster_consul_storage_server_count
  storage_backend                               = var.storage_backend
  replication_mode                              = var.replication_mode
  consul_license                                = var.consul_license
  load_balancer_mode                            = var.load_balancer_mode
  vault_license                                 = var.vault_license
  aws_account_id                                = var.aws_account_id
  aws_role_arn                                  = var.aws_role_arn
  ssh_key_name                                  = var.ssh_key_name
  vault_security_group_id                       = module.security.vault_security_group_id
  consul_security_group_id                      = module.security.consul_security_group_id
  iam_instance_profile_name                     = module.security.iam_instance_profile_name
  kms_key_arn                                   = module.network.kms_key_arn
  subnet_id_a                                   = module.network.subnet_id_a
  subnet_id_b                                   = module.network.subnet_id_b
  sandcastle_vault_primary_target_group_id      = module.load_balancer.sandcastle_vault_primary_target_group_id
  sandcastle_vault_secondary_target_group_id    = module.load_balancer.sandcastle_vault_secondary_target_group_id
}
module "load_balancer" {
  source            = "./loadbalancer"
  mode              = var.load_balancer_mode
  vpc_id            = module.network.vpc_id
  subnet_ids        = [module.network.subnet_id_a, module.network.subnet_id_b]
  security_group_id = module.security.load_balancer_security_group_id
  replication_mode  = var.replication_mode
}