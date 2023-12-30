storage "raft" {
  path = "/mnt/vault-data"
  node_id = "node-vault-prod"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
  cluster_address = "0.0.0.0:8201"
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
cluster_name = "vault-prod"
ui = true
log_level = "INFO"