auto_auth {
    method "approle" {
        config = {
            role_id_file_path = "$PWD/agent/role_id.txt"
            secret_id_file_path = "$PWD/agent/secret_id.txt"
            remove_secret_id_file_after_reading = false ##Don't do this in prod env##
        }
    }

    sink "file" {
        config = {
            path = "$PWD/agent/sink.txt"
        }
    }
}

vault {
    address = "http://VAULT_IP_ADDR:8200"
}

template {
    source = "$PWD/agent/web.tmpl"
    destination = "$PWD/agent/output.yaml"
}