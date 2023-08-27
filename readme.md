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
- **Clone the repository and CD into it**
```
git clone git@github.com:maxiscoding28/sandcastle-vault.git && cd sandcastle-vault
```
- **Initialize terraform**
```
terraform init
```
- **Grant permission to execute the bootstrap scripts:**
```
chmod u+x ./scripts/*
```
- **Verify your shell has assumed an AWS role with sufficient permissions to provision resources**
```
aws sts get-caller-identity
```
- **Ensure you have the following information:**
    - **The name of your Amazon EC2 keypair**
    - **A Vault enterprise license**
    - **A Consul enterprise license (if you're using Consul for storage)**
```
export EC2_KEY_PAIR_NAME=<YOUR SSH KEY PAIR NAME GOES HERE>

export VAULT_LICENSE=<YOUR VAULT ENTERPRISE LICENSE

export CONSUL_LICENSE=<YOUR CONSUL ENTERPRISE LICENSE>
```
- **Create a `main.tfvars` directory and add the required variables:**
```
echo "aws_account_id = \"$(aws sts get-caller-identity \
    --query 'Account' --output text)\"" >> main.tfvars

echo "aws_role_arn = \"$(aws sts get-caller-identity \
    --query 'Arn' | awk -F/ '{print $2}')\"" >> main.tfvars

curl -s 'https://api.ipify.org?format=json' | jq -r '
    "local_ip = \"\(.ip)/32\""' >> main.tfvars

echo "ssh_key_name = \"$EC2_KEY_PAIR_NAME\"" >> main.tfvars

echo "vault_license = \"$VAULT_LICENSE\"" >> main.tfvars

echo "consul_license = \"$CONSUL_LICENSE\"" >> main.tfvars
```
- **Run terraform apply to create your first vault node**
```
terraform apply -var-file=main.tfvars
```
- **Grab the  DNS Hostname for the node and SSH into it as the vault user.**
```
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=sandcastle_vault*" \
    --output table \
    --query 'Reservations[].Instances[].{ID: InstanceId, Hostname: PublicDnsName, Name: Tags[?Key==`Name`].Value | [0], Type: InstanceType, Platform: Platform || `Linux`}'

# export HOSTNAME=<HOSTNAME FROM PREVIOUS COMMAND>
# export PATH_TO_SSH_KEY=<FULL FILE PATH TO YOUR SSH KEY>

ssh -i $PATH_TO_SSH_KEY -A vault@$HOSTNAME
```
- **After SSH-ing in, verify vault status and initialize the node**
```
vault status

vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json > /home/vault/init.json
```

## What else can I do?
### Bash Shortcuts
**The vault bootstrap script generates a number of utility shell aliases and functions to make it easier to interact with vault**
```
export VAULT_ADDR=http://127.0.0.1:8200

export PS1="\[\033[0;33m\]\u@\[\033[0m\]$INSTANCE_ID "

alias v="vault"

# Shortcut for vault status
alias vst="vault status"

# Shortcut for starting vault systemd
alias vstp='sudo systemctl stop vault'

# Shortcut for stopping vault systemd
alias vstr="sudo systemctl start vault"

# Shortcut for stopping and restarting vault systemd
alias vrst="sudo systemctl stop vault && sudo systemctl start vault"

# Shortcut for tailing vault systemd logs
alias vl="journalctl -f -u vault"

# Shortcut for quickly initializing vault with 1 recovery key (useful for quick testing purposes)
alias vinit="vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json > /home/vault/init.json"

# Shortcut for opening the current vault configuration file in vim
alias vc="sudo vim /etc/vault.d/config.hcl"

# Shortcut for printing the current vault configuration file to the terminal
alias pc="cat /etc/vault.d/config.hcl"

# Shortcut for printing the current VAULT_ADDR
alias va="echo \$VAULT_ADDR"

# Shortcut for logging in with root token (assumes /home/vault/init.json has been created with vinit)
alias vrt="cat /home/vault/init.json  | jq -r '.root_token' | vault login -"

# Shortcuts for switching between http/https for VAULT_ADDR
alias http="echo \$VAULT_ADDR | sed 's/http/https/'"
alias https="echo \$VAULT_ADDR | sed 's/https/http/'"

# "vault nuke" - Shortcut for stopping vault systemd and removing data directory
vn () {
    sudo systemctl stop vault
    sudo rm -rf /opt/vault/data/*
}
```
**If you are using Consul storage, similar commands are created for interacting with Consul on both the client and server agents**
```
export PS1="\[\033[0;31m\]\u@\[\033[0m\]$INSTANCE_ID "

# Shortcut for printing the current consul configuration file to the terminal
alias pc="cat /etc/consul.d/config.hcl"

# Shortcut for opening the current consul configuration file in vim
alias vc="sudo vim /etc/consul.d/config.hcl"

# Shortcut for tailing consul systemd logs
alias cl="journalctl -f -u consul"

# "consul nuke" - Shortcut for stopping consul systemd and removing data directory
vn () {
    sudo systemctl stop consul
    sudo rm -rf /opt/consul/data/*
}
```
### Replication mode
**Adding the following variable to your `main.tfvars` will configure two separate vault cluster (primary and secondary) which can be independtently scaled. This allows for testing replication scenarios.**
```
replication_mode = true
```
### Auto-join with ASG scale-in/scale-out
**Scale your vault cluster in and out by updating the `primary_cluster_server_count` variable and/or `secondary_cluster_server_count` variable (if in `replication_mode`). New nodes will automatically join their respective cluster via cloud auto-join and retry_join**.

### Consul mode
**To use vault nodes with a Consul backend, simply add the following variables to your `main.tfvars` file:**
```
storage_backend = "consul"

# This value has to be greater than 0 if you are provisioning new nodes for the primary cluster
primary_cluster_consul_storage_server_count = 1

# This value to be greater than 0 if replication is enabled and you are provisioning new nodes for the secondary cluster
secondary_cluster_consul_storage_server_count
```
### Dynamic Versioning
**Both the vault and consul versions for new nodes can be updated using the following variables in your `main.tfvars` file:**
```
vault_version = "1.13.1+ent"
consul_version = "1.15.0+ent"
```
**If you set these values to a non-enterprise version, you do not need to provide the variables `vault_license` and `consul_license`**
### Load Balancer Mode
**The variable `load_balancer_mode` provisions a pre-configured load balancer, listener and target group pointed at the ASG for your primary Vault cluster. If `replication_mode` is enabled it will also provision one for your secondary cluster. The available values for this variable are:**
```
# Creates an application load balancer
load_balancer_mode = "alb"

# Creates a network load balancer
load_balancer_mode = "nlb"

# Default - no load balancer is created
load_balancer_mode = "none"
```
### Add Agent
_In Progress_
### Add Lambda
_In ProgresS_
