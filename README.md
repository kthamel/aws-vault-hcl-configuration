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

# 7. Secret engines - AWS IAM Role

vault secrets enable -path=aws -description="aws credentials" aws
vault write aws/config/root access_key=ACCESS_KEY_ID secret_key=SECRET_ACCESS_KEY_ID region=WORKING_REGION
vault read aws/config/root
vault write -f aws/config/rotate-root #To generate AWS access keys. Better to use seperate AWS user for vault tasks
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
vault write aws/roles/s3-role credential_type=iam_user policy_arns=arn:aws:iam::aws:policy/AmazonS3FullAccess 
/# Other than using the policy documents, we can use the ARN of the required IAM ROLE #/

vault read aws/roles/ROLE_NAME   #Read the existing role on aws secrets engine
vault delete aws/roles/ROLE_NAME #Delete the existing role on aws secrets engine
vault read aws/creds/ROLE_NAME #To generate credentials using the created roles
vault lease revoke LEASE_ID #From this command, can revoke the generated credentials
vault lease revoke -prefix aws/creds/ROLE_NAME #Can delete all the users created with this role

# 8. Secret Engine - Cubbyhole

curl --header "X-Vault-Token: hvs.VAULT_TOKEN" --request POST --data '{"Name": "test-name"}' http://VAULT_IP:8200/v1/cubbyhole/test-data #Write into cubbyhole via API call

curl --header "X-Vault-Token: hvs.VAULT_TOKEN" http://VAULT_IP:8200/v1/cubbyhole/test-data | jq #Read data from cubbyhole via API call

vault kv get -wrap-ttl=10m new-static-v1/data/test #Wrap specific secret with TTL
vault token lookup WRAPPED_TOKEN
vault unwrap WRAPPED_TOKEN #Read the wrapped data

# 9. Secret Engine - Transit

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

# 10. Secret engines - AWS Assumed Role

vault write aws/roles/assume-s3-role credential_type=assumed_role \ role_arns=arn:aws:iam::AWS_ACCOUNT_ID_OF_DIFFERENT_ACCOUNT:role/AmazonS3FullAccess 
vault write aws/sts/assume-s3-role -ttl=60m #In here have to use the write option
/# Using the command output, have to configure the AWS Cli with the STS token and access keys#/

# 11. Secret Engine - KV_V1

vault secret enable -descrption="version 01" -path="static" kv
vault kv put static/data/uat hosts="us-east-02.local" password="xyz987" user="kthamel-x"
vault kv list static/data #Can list the secrets inside the specific path
vault kv get static/data/uat #Get the secrets added into uat
vault kv get -format=json static/data/dev #Retrieve data on JSON format
vault kv get -format=json static/data/dev | jq -r ".data" #Get only the data section

# 12. Secret Engine - KV_V2

vault secrets enable -path="new-static-v2" -description="static credentials" kv-v2
vault secrets enable -path="new-static-v2" -description="static credentials" -version=2 kv #Also, this is working
vault kv enable-versioning static/ #Upgrade the kv version from 1 to version 2
vault kv get -version=1 new-static-v2/devops/dev #Get specific version, use -version 
vault kv delete new-static-v2/devops/dev data/test #Delete secret from kv
vault kv undelete -versions=3 new-static-v2devops/dev #Undo the deletion of the secret from kv 
vault kv get -version=1 -format=json static-v2/devops/dev | jq -r ".data.data.password" #Get the specific value 
vault kv destroy -versions=1 static-v2/devops/dev #Permanently delete the specific version
vault kv rollback -version=2 static-v2/devops/dev #Set specific version into the latest version
vault kv patch static-v2/devops/dev password=xyz123 #Only change the one value of a secret
vault kv metadata get static-v2/devops/dev #Get detailed metadata of a secret
vault kv metadata delete static-v2/devops/dev #Delete metadata of deleted secret

# 12. Secret Engine - Dtabase

vault secrets enable -path="vaultsql" -description="mysql backend" database #Enable database backend
vault write vaultsql/config/mysql-database plugin_name=mysql-rds-database-plugin connection_url="{{username}}:{{password}}@tcp(FQDN_OF_RDS_MYSQL_DATABASE:3306)/" allowed_roles="advanced" username="uservault" password="Vaultpassword"
/# Will prompt the message as "Success! Data written to: vaultsql/config/mysql-database" #/

vault write vaultsql/roles/advanced db_name=vault-database creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT ON *.* TO '{{name}}'@'%';" default_ttl="1h" max_ttl="24h"
/# Will prompt the message as "Success! Data written to: vaultsql/roles/advanced" #/

vault read vaultsql/roles/advanced #Read the created role name advanced
vault read vaultsql/config/mysql-database #

vault write -f vaultsql/rotate-root/mysql-database #Can rotate the username and password of RDS Database
vault read vaultsql/creds/advanced #Generate dynamic credentials (username and passwords)
/#Be caureful executing this command, better to use different MySQL user to authenticate the Database other than root #/

# 13. PKI Secret Engine

vault secrets enable -path=vaultpki -description="pki engine" pki #Enable PKI engine
vault secrets tune -max-lease-ttl=87600h vaultpki #Set max TTL to 10 years

vault write -field=certificate vaultpki/root/generate/internal common_name="kthamel.dev" ttl=87600h > kthamel_dev.crt

vault write vaultpki/config/urls issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

vault secrets enable -path=vaultpki2 -description="pki engine II" pki #Enable PKI engine #Enable intermediate PKI Engine

vault write -format=json vaultpki2/intermediate/generate/internal common_name="kthamel.dev Intermediate Authority" | jq -r ".data.csr" > pki_kthamel_dev.csr

vault write -format=json vaultpki/root/sign-intermediate csr=@pki_kthamel_dev.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate_kthamel_dev.pem

vault write vaultpki2/intermediate/set-signed certificate=@intermediate_kthamel_dev.pem
vault write vaultpki2/roles/vault_root allowed_domains="kthamel.dev" allow_subdomains=true max_ttl="720h"
vault list vaultpki2/roles
vault write vaultpki2/issue/vault_root common_name="one.kthamel.dev" ttl="24h" #Create the certificates
