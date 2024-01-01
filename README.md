# Prod Vault #

# 1. Basic vault configurations.

sudo systemctl start vault
sudo journalctl -u vault
sudo touch /var/log/vault.log
sudo chown vault:vault /var/log/vault.log
vault audit enable file file_path=/var/log/vault.log

# 2. Initialize the vault
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init
vault operator unseal
vault login

# 3. Create a vault user with root privilages

cat policy-root.hcl <<-EOF
path "*" {
capabilities = ["create", "read", "update", "delete", "list", "sudo"]
} 
EOF

vault auth write userpass
vault policy write policy-root policy-root.hcl
vault write auth/userpass/users/kthamel-a password=asitlk8s policies=policy-root

# 4. Enable new secrets path
vault secrets enable -path=aws aws  #In here aws means auth method
vault secrets tune -description="aws credentials" aws/

# 5. Enable approle auth method
vault auth enable -description="role based authentication" approle
vault write auth/approle/role/role-devops policies=policy-devops token_ttl=60m
vault list auth/approle/role
vault read auth/approle/role/role-devops
vault read auth/approle/role/role-devops/role-id #Fetch the role_id 
vault write -force auth/approle/role/role-devops/secret-id #Fetch the secret_id
vault write auth/approle/login role_id=xxxx secret_id=xyxy #Fetch the token for authentication



######################################
7. Remove the newly added path 
vault secrets disable aws/

8. Add secrets for new vault user
vault write auth/userpass/users/kthamel-a password=asitlk8s policies=root

9. Preview the added secrets 
vault kv get aws/administrator/user
vault kv get aws/administrator/password

10. Configure logs for the vault service
sudo touch /var/log/vault.log
sudo chown vault:vault /var/log/vault.log
vault audit enable file file_path=/var/log/vault.log

11. List auth methods
vault auth list

12. Update the description of a secret


13. Enable auth aws for -path=aws-data
vault auth enable -path=aws-data aws

14. Update the description of a auto method
vault auth tune -description="aws credentials" aws-data/

15. Enable bash completion for vautl
vault -autocomplete-install && source $HOME/.bashrc

16. List the vault policies list 
vault policy list


