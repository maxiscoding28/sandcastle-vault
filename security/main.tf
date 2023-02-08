#   _____________________________  ____ _____________.___________________.___.
#  /   _____/\_   _____/\_   ___ \|    |   \______   \   \__    ___/\__  |   |
#  \_____  \  |    __)_ /    \  \/|    |   /|       _/   | |    |    /   |   |
#  /        \ |        \\     \___|    |  / |    |   \   | |    |    \____   |
# /_______  //_______  / \______  /______/  |____|_  /___| |____|    / ______|
#         \/         \/         \/                 \/                \/       
variable "kms_key_arn" {
  type    = string
  default = "*"
}
variable "local_ip" {
  type    = string
  default = "0.0.0.0/0"
}
variable "aws_account_id" {
  type = string
}
variable "aws_role_arn" {
  type = string
}
variable "vpc_id" {
  type = string
}

resource "aws_iam_policy" "sandcastle_vault_kms_unseal" {
  name        = "sandcastle_vault_kms_unseal"
  description = "My KMS unseal policy for Vault Sandcastle"

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
  description = "My auto join policy for Vault Sandcastle"

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
  name                = "sandcastle_vault"
  assume_role_policy  = <<EOF
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
  managed_policy_arns = [resource.aws_iam_policy.sandcastle_vault_kms_unseal.arn, resource.aws_iam_policy.sandcastle_vault_auto_join.arn]
}

resource "aws_iam_instance_profile" "sandcastle_vault" {
  name = "sandcastle_vault"
  role = aws_iam_role.sandcastle_vault.name

  provisioner "local-exec" {
    command = "echo iam_instance_profile_name = \\\"${aws_iam_instance_profile.sandcastle_vault.name}\\\" | tee -a ../servers/main.tfvars"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "find ../servers -name \"main.tfvars\" -exec sed -i '' -e '/^iam_instance_profile_name/d' {} \\;"
  }
}

resource "aws_security_group" "sandcastle_vault" {
  name        = "sandcastles-vault-sg"
  description = "Allow SSH inbound traffic from local machine"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
  }

  ingress {
    from_port = 8200
    to_port   = 8201
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sandcastle_vault"
  }

  provisioner "local-exec" {
    command = "echo security_group_id = \\\"${aws_security_group.sandcastle_vault.id}\\\" | tee -a ../servers/main.tfvars"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "find ../servers -name \"main.tfvars\" -exec sed -i '' -e '/^security_group_id/d' {} \\;"
  }
}

output "security_group_id" {
  value = aws_security_group.sandcastle_vault.id
}
output "iam_instance_profile_name" {
  value = aws_iam_instance_profile.sandcastle_vault.name
}