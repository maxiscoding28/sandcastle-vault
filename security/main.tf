#   _____________________________  ____ _____________.___________________.___.
#  /   _____/\_   _____/\_   ___ \|    |   \______   \   \__    ___/\__  |   |
#  \_____  \  |    __)_ /    \  \/|    |   /|       _/   | |    |    /   |   |
#  /        \ |        \\     \___|    |  / |    |   \   | |    |    \____   |
# /_______  //_______  / \______  /______/  |____|_  /___| |____|    / ______|
#         \/         \/         \/                 \/                \/       
resource "aws_iam_policy" "sandcastle_vault_kms_unseal" {
  name        = "sandcastle_vault_kms_unseal"
  description = "KMS unseal policy for Vault Sandcastle"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = "${var.kms_key_arn}"
      },
    ]
  })
}
resource "aws_iam_policy" "sandcastle_vault_auto_join" {
  name        = "sandcastle_vault_auto_join"
  description = "Auto join policy for Vault Sandcastle"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
resource "aws_iam_role" "sandcastle_vault" {
  name               = "sandcastle_vault"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.aws_account_id}:role/${var.aws_role_arn}",
                "Service": "ec2.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:SetSourceIdentity"
            ]
        }
    ]
  }
  EOF
  managed_policy_arns = [
    resource.aws_iam_policy.sandcastle_vault_kms_unseal.arn,
    resource.aws_iam_policy.sandcastle_vault_auto_join.arn
  ]
}
resource "aws_iam_instance_profile" "sandcastle_vault" {
  name = "sandcastle_vault"
  role = aws_iam_role.sandcastle_vault.name
}
resource "aws_security_group" "sandcastle_vault" {
  name        = "sandcastle_vault_sg"
  description = "Security group for a Vault cluster using Integrated Storage"
  vpc_id      = var.vpc_id
  tags = {
    Name = "sandcastle_vault"
  }
}
resource "aws_vpc_security_group_ingress_rule" "sandcastle_vault_ssh_from_local" {
  description       = "SSH from local IP"
  security_group_id = aws_security_group.sandcastle_vault.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.local_ip
}
resource "aws_vpc_security_group_ingress_rule" "sandcastle_vault_intta_cluster" {
  description                  = "Intra-cluster TCP communication for Vault"
  security_group_id            = aws_security_group.sandcastle_vault.id
  from_port                    = 8200
  to_port                      = 8201
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.sandcastle_vault.id
}
resource "aws_vpc_security_group_ingress_rule" "sandcastle_vault_tcp_from_local" {
  count             = var.load_balancer_mode == "none" ? 1 : 0
  description       = "Access Vault API from local"
  security_group_id = aws_security_group.sandcastle_vault.id
  from_port         = 8200
  to_port           = 8200
  ip_protocol       = "tcp"
  cidr_ipv4         = var.local_ip
}
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.sandcastle_vault.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_security_group" "sandcastle_vault_on_consul" {
  name        = "sandcastle_vault_on_consul_sg"
  description = "Security group for a Vault cluster using Integrated Storage"
  vpc_id      = var.vpc_id
  count       = var.storage_backend == "consul" ? 1 : 0
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    self        = true
    description = "DNS queries to consul on TCP"
  }
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    self        = true
    description = "Intra-cluster DNS queries"
  }
  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    self        = true
    description = "Intra cluster RPC and LAN, inter cluster WAN on TCP"
  }
  ingress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "udp"
    self        = true
    description = "Intra cluster LAN, inter cluster WAN on UDP"
  }
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    self        = true
    description = "HTTP API access on 8500 within the security group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sandcastle_vault_on_consul"
  }
}
resource "aws_security_group" "sandcastle_vault_from_local_to_loadbalancer" {
  name        = "sandcastle_vault_from_local_to_loadbalancer_sg"
  count       = var.load_balancer_mode != "none" ? 1 : 0
  description = "Security group from local to load balancer"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
    description = "Access Vault API from local"
  }
  egress {
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [aws_security_group.sandcastle_vault.id]
  }
  tags = {
    Name = "sandcastle_vault_from_local_to_loadbalancer"
  }
}
resource "aws_vpc_security_group_ingress_rule" "sandcastle_vault_from_loadbalancer_to_vault" {
  count                        = var.load_balancer_mode != "none" ? 1 : 0
  description                  = "Access Vault cluster from the load balancer"
  security_group_id            = aws_security_group.sandcastle_vault.id
  from_port                    = 8200
  to_port                      = 8200
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.sandcastle_vault_from_local_to_loadbalancer[0].id
}

