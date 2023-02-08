#  _______  ________________________      __________ __________ ____  __.
#  \      \ \_   _____/\__    ___/  \    /  \_____  \\______   \    |/ _|
#  /   |   \ |    __)_   |    |  \   \/\/   //   |   \|       _/      <  
# /    |    \|        \  |    |   \        //    |    \    |   \    |  \ 
# \____|__  /_______  /  |____|    \__/\  / \_______  /____|_  /____|__ \
#         \/        \/                  \/          \/       \/        \/
resource "aws_vpc" "sandcastle_vault" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "sandcastle_vault"
  }
}
resource "aws_subnet" "sandcastle_vault_a" {
  vpc_id                  = aws_vpc.sandcastle_vault.id
  availability_zone       = "${var.region}a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "sandcastle_vault_a"
  }
}
resource "aws_subnet" "sandcastle_vault_b" {
  vpc_id                  = aws_vpc.sandcastle_vault.id
  availability_zone       = "${var.region}b"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "sandcastle_vault_b"
  }
}
resource "aws_internet_gateway" "sandcastle_vault" {
  vpc_id = aws_vpc.sandcastle_vault.id
  tags = {
    Name = "sandcastle_vault"
  }
}
resource "aws_default_route_table" "sandcastle_vault" {
  default_route_table_id = aws_vpc.sandcastle_vault.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sandcastle_vault.id
  }
  tags = {
    Name = "sandcastle_vault"
  }
}
resource "aws_route_table_association" "sandcastle_vault_a" {
  subnet_id      = aws_subnet.sandcastle_vault_a.id
  route_table_id = aws_vpc.sandcastle_vault.default_route_table_id
}
resource "aws_route_table_association" "sandcastle_vault_b" {
  subnet_id      = aws_subnet.sandcastle_vault_b.id
  route_table_id = aws_vpc.sandcastle_vault.default_route_table_id
}
resource "aws_kms_key" "sandcastle_vault" {
  description             = "KMS key for unsealing Vault Sandcastle cluster"
  deletion_window_in_days = 10
}