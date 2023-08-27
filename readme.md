<h1 align="center"> 🏰 Sandcastle Vault 🔑</h1>
<p align="center">
<img src="./assets/vault.svg" alt="sand-castle" width=400 height=300>
<img src="./assets/sandcastle.png" alt="sand-castle" width=400 height=300>
</p>

## Overview
Sandcastle Vault is a directory of terraform files for quickly setting up a basc Vault cluster in an AWS cloud environment.
This repository was developed with support engineers mind. It can be useful for testing, experimenting, and troubleshooting in [Hashicorp Vault](https://www.vaultproject.io/)

### What You'll Need
- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [Aws Cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed
- [jq](https://stedolan.github.io/jq/) installed
- A valid [Amazon EC2 Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html)
- An AWS account capable of creating all the required resources
- A valid [Vault Enterprise license](https://developer.hashicorp.com/vault/docs/enterprise)
- A valid [Consul Enterprise license](https://developer.hashicorp.com/consul/docs/enterprise) (if you're using Consul storage)

## Quick Start
- Clone and CD into the respository
```
git clone git@github.com:maxiscoding28/sandcastle-vault.git && cd sandcastle-vault
```
- Initialize the terraform repository
```
terraform init
```
- Grant permission to execute bootstrap scripts:
```
chmod u+x ./scripts
```
- Verify your shell has assumed an AWS role with sufficient permissions to provision resources
```
aws sts get-caller-identity
```
- Create a `main.tfvars` directory and add the required variables:
```
echo "aws_account_id = \"$(aws sts get-caller-identity \
    --query 'Account' --output text)\"" >> main.tfvars

echo "aws_role_arn = \"$(aws sts get-caller-identity \
    --query 'Arn' | awk -F/ '{print $2}')\"" >> main.tfvars

curl -s 'https://api.ipify.org?format=json' | jq -r '
    "local_ip = \"\(.ip)/32\""' >> main.tfvars

# export EC2_KEY_PAIR_NAME=<YOUR SSH KEY PAIR NAME GOES HERE>
echo "ssh_key_name = \"$EC2_KEY_PAIR_NAME\"" >> main.tfvars

# export VAULT_LICENSE=<YOUR VAULT ENTERPRISE LICENSE>
echo "vault_license = \"$VAULT_LICENSE\"" >> main.tfvars

# export CONSUL_LICENSE=<YOUR CONSUL ENTERPRISE LICENSE>
# *if you're using Consul storage
echo "consul_license = \"$CONSUL_LICENSE\"" >> main.tfvars
```
- Run terraform apply to create your first Vault node
```
terraform apply -var-file=main.tfvars
```
- Grab the  DNS Hostname for the node and SSH into it as the vault user.
```
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=sandcastle_vault*" \
    --output table \
    --query 'Reservations[].Instances[].{ID: InstanceId, Hostname: PublicDnsName, Name: Tags[?Key==`Name`].Value | [0], Type: InstanceType, Platform: Platform || `Linux`}'

# export HOSTNAME=<HOSTNAME FROM PREVIOUS COMMAND>
# export PATH_TO_SSH_KEY=<FULL FILE PATH TO YOUR SSH KEY>
ssh -i $PATH_TO_SSH_KEY -A vault@$HOSTNAME
```

- Verify vault status and initialize the node
```
vault status

vault operator init -key-shares=1 -key-threshold=1 > /home/vault/init.json
```

## What else can I do?
### Bash Shortcuts
### Consul mode
### Auto-join with ASG scale-in/scale-out
### Dynamic Versioning
### Replication mode
### Load Banacer Mode
#### alb
#### nlb
### Add Agent
_In Progress_
### Add Lambda
_In ProgresS_
