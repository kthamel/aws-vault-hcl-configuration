#!/bin/bash

echo "## Install HashiCorp Vault ##"
sudo wget -O /mnt/vault-file.zip https://releases.hashicorp.com/vault/1.15.4/vault_1.15.4_linux_amd64.zip
sudo cd /mnt
sudo unzip /mnt/vault-file.zip
sudo mv vault /usr/local/bin/

echo "## Attach the volume ##"
sudo mkfs.ext4 -F /dev/xvdk
sudo mount /dev/xvdk /mnt
sudo mkdir /mnt/vault-data

echo "## Create user for vault service ##"
sudo useradd -m -d /mnt/vault-data vault

echo "## Copy the valut.hcl file ##"
sudo mkdir /etc/vault.d/
sudo cp -rv aws-vault-hcl-configuration/vault.hcl /etc/vault.d/

echo "## Copy the vault.service file ##"
sudo cp -rv aws-vault-hcl-configuration/vault.service /lib/systemd/system/

echo "## Start the vault service ##"
sudo systemctl start vault.service