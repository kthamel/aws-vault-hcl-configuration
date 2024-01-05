# Prod Vault #

# 1. Basic vault configurations.

vault --version
sudo systemctl start vault
sudo journalctl -u vault
vault -autocomplete-install && source $HOME/.bashrc
sudo touch /var/log/vault.log
sudo chown vault:vault /var/log/vault.log
vault audit enable file file_path=/var/log/vault.log

# 2. Initialize the vault

export VAULT_ADDR='http://127.0.0.1:8200' #If you ssh into the instance
export VAULT_ADDR='http://accessible_ip:8200'
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

# 6. Authenticate with tokens

vault token create -policy="policy-devops" #Creating a custom token using the specific policy + default
cat ~/.vault-token
vault token lookup token_value_XXXX #Can use the output of above command
vault token create -policy="policy-devops-plus" -use-limit=2 #Create new token with use limits
vault token create -policy="policy-devops-plus" -use-limit=2 -ttl=1h #Create new token with TTL value
vault token create -policy="policy-devops-plus" -orphan #Create orphan token
vault write auth/approle/role/devops policies="policy-devops" token_type="batch" token_ttl="60s" #Create batch token
vault read auth/approle/role/devops
vault token revoke hvs.xxxxxxxxx #If token is existing, can revoke it
vault token lookup -accessor accessor_id_xxxx #Get more deails of token
vault token revoke -accessor accessor_id_xxxx #If token is existing, can revoke it
vault write auth/approle/role/devops policies="policy-devops" token_type="batch" token_ttl="300s" token_max_ttl="3000s" #Create batch token with maximum TTL

# 7. Secret engines - AWS

vault secrets enable -path=aws -description="aws credentials" aws
vault write aws/config/root access_key=ACCESS_KEY_ID secret_key=SECRET_ACCESS_KEY_ID region=us-east-1 
#Write the privialge user credentials to the AWS Secret engine
#Create a new role inside the AWS secrets engine

vault write aws/roles/ec2-role \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF

vault list aws/roles    #List the existing roles on aws secrets engine
vault read aws/roles/   #Read the existing role on aws secrets engine
vault delete aws/roles/ #Delete the existing role on aws secrets engine

# 8. Secret Engine - KV [version 1 and 2]

vault secrets list -detailed #List secret engines with more details
vault secrets enable -path="static" -description="static credentials" kv #Create secret engine for static secrets
vault kv put -mount=static devops/dev user=kthamel-1 hosts=us-east-01.local password=abc123 #Put static data into kv
vault secrets enable -path="static-v2" -description="static credentials" kv-v2 #Enable kv from version 2. Just kv is v1
vault secrets enable -path="new-static-v2" -description="static credentials" -version=2 kv #Also, this is working
vault kv enable-versioning static/ #Upgrade the kv version from 1 to version 2
vault kv delete -mount=new-static-v2 data/test #Delete secret from kv [version 2 only]
vault kv undelete -mount=new-static-v2 -versions=3 data/test #Undo the deletion of the secret from kv [version 2 only]
vault kv destroy -mount=new-static-v2 -versions=3 data/test #Delete permanently, unable to undelete and recover
vault kv rollback -mount=new-static-v2 -version=2 data/test #Rollback can set a version into the latest version
vault kv patch -mount=new-static-v2 data/test password=xyz123 #Only change the once value of a secret [version 2 only]
vault kv get -version=5 new-static-v2/data/test #Get secrets of specific version

# 9. Secret Engine - Cubbyhole

curl --header "X-Vault-Token: hvs.VAULT_TOKEN" --request POST --data '{"Name": "test-name"}' http://VAULT_IP:8200/v1/cubbyhole/test-data #Write into cubbyhole via API call

curl --header "X-Vault-Token: hvs.VAULT_TOKEN" http://VAULT_IP:8200/v1/cubbyhole/test-data | jq #Read data from cubbyhole via API call

vault kv get -wrap-ttl=10m new-static-v1/data/test #Wrap specific secret with TTL
vault token lookup WRAPPED_TOKEN
vault unwrap WRAPPED_TOKEN #Read the wrapped data

# 10. Secret Engine - Transit
vault secrets enable -path="transit" -description="transit engine" transit #Enable transit engine
vault write -f transit/keys/devops type="rsa-4096" #Create encryption key using the rsa-4096 

vault write transit/encrypt/devops plaintext=$(base64 <<< "Plain text 01") 
/# In here devops is the name of encryption key. "Plain text 01" is the text that we are going to encrypt using the devops encryption key #/

vault write transit/encrypt/devopx plaintext=$(base64 <<< "Plain text 01") 
/# If we run the same command with non-existing encryption key, it will create the encryption key with the given anme and use the aes256-gcm96 #/

vault write transit/decrypt/devopx ciphertext="vault:v1:ENCRYPTED_TEXT"
/# This has to be decode using Base64 /#
echo ENCODED_VALUE | base64 --decode

vault write -f transit/keys/devops/rotate #Can rotate encryption key forcefully [pass -f option]
vault write transits/rewrap/devops ciphertext="V2_VERSION_CYPHERTEXT_VALUE" #Rewrap will be done using the latest key_version

vault write transits/decrypt/devops ciphertext=="V2_VERSION_RETURNING_CYPHERTEXT_VALUE"

vault write transits/decrypt/devops ciphertext="V3_VERSION_RETURNING_CYPHERTEXT_VALUE
/# From this way we can get the encoded that we used on first step #/

vault write transit/keys/devops/config min_decryption_version=3 #Set minimum decryption version

# 11. Secret engines - AWS IAM
