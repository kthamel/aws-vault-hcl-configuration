# Prod Vault #

# 1. Basic vault configurations.

sudo systemctl start vault
sudo journalctl -u vault
vault -autocomplete-install && source $HOME/.bashrc
sudo touch /var/log/vault.log
sudo chown vault:vault /var/log/vault.log
vault audit enable file file_path=/var/log/vault.log

# 2. Initialize the vault
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init
vault operator unseal
vault login

# 3. Create a vault user with root privilages

cat << EOF >> policy-root.hcl 
path "*" {
capabilities = ["create", "read", "update", "delete", "list", "sudo"]
} 
EOF

vault policy fmt policy-root.hcl # Canonical formating the policy document
vault auth enable userpass
vault auth tune -description="vault user credentials" userpass/
vault policy write policy-root policy-root.hcl
vault policy read policy-root
vault write auth/userpass/users/kthamel-a password=asitlk8s policies=policy-root
vault list auth/userpass/users
vault read auth/userpass/users/kthamel-a

# 4. Working with API calls
curl \ 
--header "X-Vault-Token: vault_token" \
--request GET  
http://127.0.0.1:8200/v1/sys/policy/policy-root 

# 4. Enable new secrets path
vault secrets enable -path=aws aws  #In here aws means auth method
vault secrets tune -description="aws credentials" aws/
vault secrets enable -description="ansible configuration" -path="ansible" kv # From single line
vault secrets list
vault kv put -mount=ansible dev user=kthamel-1 hosts=us-east-01.local password=abc123
vault kv list -mount=ansible
vault kv get -mount=ansible dev

# 5. Enable approle auth method
vault auth enable -description="role based authentication" approle
vault write auth/approle/role/role-devops policies=policy-devops token_ttl=60m
vault list auth/approle/role
vault read auth/approle/role/role-devops
vault read auth/approle/role/role-devops/role-id #Fetch the role_id 
vault write -force auth/approle/role/role-devops/secret-id #Fetch the secret_id
vault write auth/approle/login role_id=xxxx secret_id=xyxy #Fetch the token for authentication



######################################

9. Preview the added secrets 
vault kv get aws/administrator/user
vault kv get aws/administrator/password
