resource "vault_policy" "boundary-controller" {
  name = "boundary-controller"

  policy = <<EOT
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "sys/leases/renew" {
  capabilities = ["update"]
}

path "sys/leases/revoke" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
# the next 2 were for testing
path "ssh/issue/dymanic" {
 capabilities = ["create","update"]
}
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

EOT
}

resource "vault_policy" "kv-read" {
  name = "kv-read"

  policy = <<EOT
path "secret/data/my-secret" {
  capabilities = ["read"]
}

path "secret/data/my-app-secret" {
  capabilities = ["read"]
}
EOT
}
