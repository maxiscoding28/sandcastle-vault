export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
export REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

adduser vault
usermod -a -G systemd-journal vault
echo 'vault ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

mkdir -p /opt/vault/data
chown -R vault:vault /opt/vault/data

mkdir /etc/vault.d/
echo -e "VAULT_LICENSE=${vault_license}" > /etc/vault.d/env
chown -R vault:vault /etc/vault.d/

curl --silent -Lo /tmp/vault.zip https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip
unzip /tmp/vault.zip
mv vault /usr/bin
rm -f /tmp/vault.zip

mkdir -p /home/vault/.ssh
cat /home/ec2-user/.ssh/authorized_keys > /home/vault/.ssh/authorized_keys
chown -R vault:vault /home/vault/.ssh
chmod 700 /home/vault/.ssh
chmod 600 /home/vault/.ssh/authorized_keys


cat > /etc/systemd/system/agent.service << EOF
[Unit]
Description=Vault Agent service
Wants=network-online.target

[Service]
User=vault
Group=vault
Type=simple
ExecStart=/usr/bin/vault agent -config=/etc/vault.d/config.hcl --log-level=debug

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/vault.d/agent.config << EOF
vault {
  address = ""
}

auto_auth {
  method "approle" {
    exit_on_err = true
    min_backoff = "20s"
    max_backoff = "1m"
    config = {
      role_id_file_path   = "/etc/vault.d/role-id"
      secret_id_file_path = "/etc/vault.d/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    config = {
      path = "/etc/vault.d/token"
    }
  }
}
EOF

cat > /etc/vault.d/templat.ctmpl << EOF
{{- with secret "kv/data/pass" -}}
{{ .Data.data.max }}
{{- end -}}
EOF