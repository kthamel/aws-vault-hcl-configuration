#!/bin/bash
echo "Create user for vault service"
sudo useradd -m -d /mnt/vault-data vault

echo "Copy the valut.hcl file"
sudo cp -rv vault.hcl /etc/vault.d/

echo "Copy the vault.service file"
sudo cp -rv vault.service /lib/systemd/system/

echo "Start the vault service"
sudo systemctl start vault.service