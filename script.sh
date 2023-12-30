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
BLK_ID=$(sudo blkid /dev/xvdk | cut -f2 -d" ")
echo "$BLK_ID     /mnt   ext4    defaults   0   2" | sudo tee --append /etc/fstab
sudo mount -a

echo "## Create user for vault service ##"
sudo useradd -m -d /mnt/vault-data vault
sudo chown -Rv vault:vault /mnt/vault-data/

echo "## Copy the valut.hcl file ##"
sudo mkdir /etc/vault.d/
sudo cp -rv aws-vault-hcl-configuration/vault.hcl /etc/vault.d/

echo "## Copy the vault.service file ##"
sudo cp -rv aws-vault-hcl-configuration/vault.service /lib/systemd/system/

echo "## Enable the vault service ##"
sudo systemctl enable vault.service

echo "## Start the vault service ##"
sudo systemctl start vault.service

echo "## Enable logs for vault service ##"
touch /var/log/vault.log
chown vault:vault /var/log/vault.log
vault audit enable file file_path=/var/log/vault.log
