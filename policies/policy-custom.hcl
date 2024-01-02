path "ansible/*" {
  capabilities = ["list"]
}

path "ansible/dev" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "ansible/test" {
  capabilities = ["read", "update", "delete", "list", "sudo"]
}

path "ansible/uat" {
  capabilities = ["read", "update", "list"]
}

path "ansible/prod" {
  capabilities = ["list"]
}