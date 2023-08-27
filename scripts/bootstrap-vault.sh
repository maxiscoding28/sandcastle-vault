#!/bin/bash
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)

# Create users
adduser vault
usermod -a -G systemd-journal vault
echo 'vault ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

if [[ ${storage_backend} == "consul" ]]; then
adduser consul
usermod -a -G systemd-journal consul
echo 'consul ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo
fi

# Create data directory
if [[ ${storage_backend} == "consul" ]]; then
mkdir -p /opt/consul/data/
chown -R consul:consul /opt/consul/data
else
mkdir -p /opt/vault/data
chown -R vault:vault /opt/vault/data
fi

# Create /etc/ configuration directory and env files
mkdir /etc/vault.d/
echo -e "VAULT_LICENSE=${vault_license}\nVAULT_AWSKMS_SEAL_KEY_ID=${kms_key_arn}" > /etc/vault.d/env
chown -R vault:vault /etc/vault.d/

if [[ ${storage_backend} == "consul" ]]; then
mkdir /etc/consul.d/
echo -e "CONSUL_LICENSE=${consul_license}" > /etc/consul.d/env
chown -R consul:consul /etc/consul.d/
fi

# Copy .ssh keys from ec2-user to vault user so you can ssh
# into the ec2 instance as vault.
mkdir -p /home/vault/.ssh
cat /home/ec2-user/.ssh/authorized_keys > /home/vault/.ssh/authorized_keys
chown -R vault:vault /home/vault/.ssh
chmod 700 /home/vault/.ssh
chmod 600 /home/vault/.ssh/authorized_keys

# Install Vault (and optionally Consul) binaries
curl --silent -Lo /tmp/vault.zip https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip
unzip /tmp/vault.zip
mv vault /usr/bin
rm /tmp/vault.zip

if [[ ${storage_backend} == "consul" ]]; then
curl --silent -Lo /tmp/consul.zip https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
unzip /tmp/consul.zip
mv consul /usr/bin
rm -f /tmp/consul.zip
fi

# Create systemd configuration file(s)
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

if [[ ${storage_backend} == "consul" ]]; then
cat > /etc/systemd/system/consul.service << EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/config.hcl

[Service]
Type=notify
User=consul
Group=consul
EnvironmentFile=/etc/consul.d/env
ExecStart=/usr/bin/consul agent -config-file=/etc/consul.d/config.hcl
ExecReload=/usr/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
fi

# Create configuration files
if [[ ${storage_backend} == "consul" ]]; then
cat > /etc/vault.d/config.hcl << EOF
listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_disable = 1
}
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
seal "awskms" {
  region = "${region}"
  disabled = "false"
}
api_addr = "http://{{ GetPrivateInterfaces | attr \"address\" }}:8200"
cluster_addr = "http://{{ GetPrivateInterfaces | attr \"address\" }}:8201"
cluster_name = "${cluster}-vault-cluster"
ui = true
log_level = "info"
raw_storage_endpoint = true
enable_response_header_hostname = true
enable_response_header_raft_node_id = true
EOF

cat > /etc/consul.d/config.hcl << EOF
log_level  = "INFO"
server     = false
datacenter = "${cluster}-consul-dc"
primary_datacenter = "${cluster}-consul-dc"
node_name = "${cluster}-cluster-client-$INSTANCE_ID"
encrypt            = "pCOEKgL2SYHmDoFJqnolFUTJi7Vy+Qwyry04WIZUupc="
data_dir           = "/opt/consul/data"
client_addr    = "0.0.0.0"
retry_join = ["provider=aws tag_key=join tag_value=sandcastle_vault_consul_storage_${cluster} region=${region}"]
connect {
  enabled = true
}
ui_config {
  enabled = true
}
acl {
  enabled = true
  default_policy = "allow"
  down_policy = "extend-cache"
}
EOF
else
cat > /etc/vault.d/config.hcl << EOF
listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_disable = 1
}
storage "raft" {
  path = "/opt/vault/data"
  node_id = "$INSTANCE_ID"
  retry_join {
    auto_join = "provider=aws region=${region} tag_key=join tag_value=sandcastle_vault_${cluster}"
    auto_join_scheme = "http"
  }
}
seal "awskms" {
  region = "${region}"
  disabled = "false"
}
api_addr = "http://{{ GetPrivateInterfaces | attr \"address\" }}:8200"
cluster_addr = "http://{{ GetPrivateInterfaces | attr \"address\" }}:8201"
cluster_name = "${cluster}-vault-cluster"
ui = true
log_level = "info"
raw_storage_endpoint = true
enable_response_header_hostname = true
enable_response_header_raft_node_id = true
EOF
fi

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

# "vault nuke" - Shortcut for stopping vault systemd and removing data directory
vn () {
    sudo systemctl stop vault
    sudo rm -rf /opt/vault/data/*
}
EOF

if [[ ${storage_backend} == "consul" ]]; then
cat > /etc/profile.d/consul.sh << EOF
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
EOF
fi

# Start services
if [[ ${storage_backend} == "consul" ]]; then
systemctl start consul
fi
systemctl start vault
