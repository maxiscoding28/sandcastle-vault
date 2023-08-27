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
- Grant permission to execute bootstrap scripts:
```
chmod u+x ./scripts
```
- Set vars you need
- Create you first Vault node
- Scale up
- Scale down

## What else can I do?
### Consul mode
### Dynamic Versioning
### Replication mode
### Load Banacer Mode
#### alb
#### nlb
### Add Agent
_In Progress_
### Add Lambda
_In ProgresS_