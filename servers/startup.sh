#!/bin/bash
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
export REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

# Create user
adduser vault
usermod -a -G systemd-journal vault
echo 'vault ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

# Create raft storage and grant ownership
mkdir -p /opt/vault/data
chown -R vault:vault /opt/vault/data

# Create vault config directory and env file for systemd
mkdir /etc/vault.d/
echo -e "VAULT_LICENSE=${vault_license}\nVAULT_AWSKMS_SEAL_KEY_ID=${kms_key_arn}" > /etc/vault.d/env
chown -R vault:vault /etc/vault.d/

# Copy .ssh keys from ec2-user to vault user so you can ssh
# into the ec2 instance as vault.
mkdir -p /home/vault/.ssh
cat /home/ec2-user/.ssh/authorized_keys > /home/vault/.ssh/authorized_keys
chown -R vault:vault /home/vault/.ssh
chmod 700 /home/vault/.ssh
chmod 600 /home/vault/.ssh/authorized_keys

# Install the vault binary with curl
# Unzip the vault.zip, move binary to /usr/bin and rm vault.zip file
curl --silent -Lo /tmp/vault.zip https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip
unzip /tmp/vault.zip
mv vault /usr/bin
rm /tmp/vault.zip

# Create systemd file
cat > /etc/systemd/system/vault.service << EOF
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/config.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=false
ProtectHome=false
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
EnvironmentFile=/etc/vault.d/env
ExecStart=/usr/bin/vault server -config=/etc/vault.d/config.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity
Type=notify

[Install]
WantedBy=multi-user.target
EOF

# Create vault server config file
cat > /etc/vault.d/config.hcl << EOF
listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_disable = 1
}

storage "raft" {
  path = "/opt/vault/data"
  node_id = "$INSTACE_ID"
  retry_join {
    auto_join = "provider=aws region=${region} tag_key=join tag_value=sandcastle_vault_${cluster}"
    auto_join_scheme = "http"
  }
}

seal "awskms" {
  region = "$REGION"
  disabled = "false"
}

# Make these gosockaddr private IP
api_addr = "http://$(curl -s http://169.254.169.254/latest/meta-data/public-hostname):8200"
cluster_addr = "http://$(curl -s http://169.254.169.254/latest/meta-data/public-hostname):8201"

cluster_name = "vault-${cluster}-cluster"
ui = true
log_level = "info"
raw_storage_endpoint = true
enable_response_header_hostname = true
enable_response_header_raft_node_id = true
EOF

# Create bash helper commands
cat > /etc/profile.d/vault.sh << EOF
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

# "vault nuke" - Shortcut for stopping vault systemd and remove data directory
vn () {
    sudo systemctl stop vault
    sudo rm -rf /opt/vault/data/*
}
EOF

systemctl start vault