# .____    ________      _____  ________ __________    _____  .____       _____    _______  _________ _____________________  _________
# |    |   \_____  \    /  _  \ \______ \\______   \  /  _  \ |    |     /  _  \   \      \ \_   ___ \\_   _____/\______   \/   _____/
# |    |    /   |   \  /  /_\  \ |    |  \|    |  _/ /  /_\  \|    |    /  /_\  \  /   |   \/    \  \/ |    __)_  |       _/\_____  \ 
# |    |___/    |    \/    |    \|    `   \    |   \/    |    \    |___/    |    \/    |    \     \____|        \ |    |   \/        \
# |_______ \_______  /\____|__  /_______  /______  /\____|__  /_______ \____|__  /\____|__  /\______  /_______  / |____|_  /_______  /
#         \/       \/         \/        \/       \/         \/        \/       \/         \/        \/        \/         \/        \/
resource "aws_lb" "sandcastle_vault_primary_alb" {
  count              = var.mode == "alb" ? 1 : 0
  name               = "sandcastle-vault-primary-alb"
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
}
resource "aws_lb" "sandcastle_vault_secondary_alb" {
  count              = var.mode == "alb" && var.replication_mode ? 1 : 0
  name               = "sandcastle-vault-secondary-alb"
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
}
resource "aws_lb_target_group" "sandcastle_vault_primary_alb" {
  count                = var.mode == "alb" ? 1 : 0
  name                 = "sandcastle-vault-primary-alb"
  port                 = "8200"
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 10
  health_check {
    healthy_threshold = 2
    interval          = 30
    path              = "/v1/sys/health"
    timeout           = 10
    matcher           = "200,473"
  }
}
resource "aws_lb_target_group" "sandcastle_vault_secondary_alb" {
  count                = var.mode == "alb" && var.replication_mode ? 1 : 0
  name                 = "sandcastle-vault-secondary-alb"
  port                 = "8200"
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 10
  health_check {
    healthy_threshold = 2
    interval          = 30
    path              = "/v1/sys/health"
    timeout           = 10
    matcher           = "200,473"
  }
}
resource "aws_lb_listener" "sandcastle_vault_primary_alb" {
  count             = var.mode == "alb" ? 1 : 0
  load_balancer_arn = aws_lb.sandcastle_vault_primary_alb[0].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sandcastle_vault_primary_alb[0].arn
  }
}
resource "aws_lb_listener" "sandcastle_vault_secondary_alb" {
  count                = var.mode == "alb" && var.replication_mode ? 1 : 0
  load_balancer_arn = aws_lb.sandcastle_vault_secondary_alb[0].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sandcastle_vault_secondary_alb[0].arn
  }
}
resource "aws_lb" "sandcastle_vault_primary_nlb" {
  count              = var.mode == "nlb" ? 1 : 0
  name               = "sandcastle-vault-primary-nlb"
  load_balancer_type = "network"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
}
resource "aws_lb" "sandcastle_vault_secondary_nlb" {
  count                = var.mode == "nlb" && var.replication_mode ? 1 : 0
  name               = "sandcastle-vault-secondary-nlb"
  load_balancer_type = "network"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
}
resource "aws_lb_target_group" "sandcastle_vault_primary_nlb" {
  count                = var.mode == "nlb" ? 1 : 0
  name                 = "sandcastle-vault-primary-nlb"
  port                 = "8200"
  protocol             = "TCP"
  vpc_id               = var.vpc_id
  deregistration_delay = 10
  health_check {
    healthy_threshold = 2
    interval          = 30
    path              = "/v1/sys/health"
    timeout           = 10
    matcher           = "200,473"
  }
}
resource "aws_lb_target_group" "sandcastle_vault_secondary_nlb" {
  count                = var.mode == "nlb" && var.replication_mode ? 1 : 0
  name                 = "sandcastle-vault-secondary-nlb"
  port                 = "8200"
  protocol             = "TCP"
  vpc_id               = var.vpc_id
  deregistration_delay = 10
  health_check {
    healthy_threshold = 2
    interval          = 30
    path              = "/v1/sys/health"
    timeout           = 10
    matcher           = "200,473"
  }
}
resource "aws_lb_listener" "sandcastle_vault_primary_nlb" {
  count             = var.mode == "nlb" ? 1 : 0
  load_balancer_arn = aws_lb.sandcastle_vault_primary_nlb[0].arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sandcastle_vault_primary_nlb[0].arn
  }
}
resource "aws_lb_listener" "sandcastle_vault_secondary_nlb" {
  count                = var.mode == "nlb" && var.replication_mode ? 1 : 0
  load_balancer_arn = aws_lb.sandcastle_vault_secondary_nlb[0].arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sandcastle_vault_secondary_nlb[0].arn
  }
}
output "sandcastle_vault_primary_target_group_id" {
  value = var.mode == "alb" ? aws_lb_target_group.sandcastle_vault_primary_alb[0].id : var.mode == "nlb" ? aws_lb_target_group.sandcastle_vault_primary_nlb[0].id : ""
}
output "sandcastle_vault_secondary_target_group_id" {
  value =  var.mode == "alb" && var.replication_mode ? aws_lb_target_group.sandcastle_vault_secondary_alb[0].id : var.mode == "nlb" && var.replication_mode ? aws_lb_target_group.sandcastle_vault_secondary_nlb[0].id : ""
}

