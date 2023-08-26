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
#ALB
resource "aws_lb" "sandcastle_vault_primary" {
  count              = var.mode == "alb" ? 1 : 0
  name               = "sandcastle-vault-primary"
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
}
resource "aws_lb_target_group" "sandcastle_vault_primary" {
  count    = var.mode == "alb" ? 1 : 0
  name     = "sandcastle-vault-primary"
  port     = "8200"
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    healthy_threshold = 2
    interval = 30
    path = "/v1/sys/health"
    timeout = 10
    matcher = "200,473"
  }
}
resource "aws_lb_listener" "sandcastle_vault_primary" {
  count             = var.mode == "alb" ? 1 : 0
  load_balancer_arn = aws_lb.sandcastle_vault_primary[0].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sandcastle_vault_primary[0].arn
  }
}

#NLB


output "sandcastle_vault_primary_target_group_id" {
  value = var.mode == "alb" ? aws_lb_target_group.sandcastle_vault_primary[0].id : ""
}


