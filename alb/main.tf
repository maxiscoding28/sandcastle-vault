variable "subnet_id_a" {
  type = string
}
variable "subnet_id_b" {
  type = string
}
variable "security_group_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "sandcastle_primary_asg_id" {
  type = string
}
resource "aws_lb" "sandcastle_vault" {
  name               = "sandcastle-vault"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = [var.subnet_id_a, var.subnet_id_b]
  tags = {
    Name = "sandcastle_vault"
  }
}

resource "aws_lb_target_group" "sandcastle_vault" {
  name     = "sandcastle-vault"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/v1/sys/health"
    protocol            = "HTTP"
    port                = "8200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

resource "aws_autoscaling_attachment" "sandcastle_vault" {
  autoscaling_group_name = "sandcastle_vault_primary"
  lb_target_group_arn    = aws_lb_target_group.sandcastle_vault.arn
}

resource "aws_lb_listener" "sandcastle_vault" {
  load_balancer_arn = aws_lb.sandcastle_vault.arn
  port              = "8200"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sandcastle_vault.arn
  }
}