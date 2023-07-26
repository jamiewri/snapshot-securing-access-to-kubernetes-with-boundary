resource "boundary_credential_library_vault" "read-only" {
  name                = "read-only"
  description         = "Vault Dynamic Kubernetes Secerets Engine"
  credential_store_id = boundary_credential_store_vault.vault-cred-store.id
  path                = "kubernetes/creds/read-only"
  http_method         = "POST"
  http_request_body   = <<EOT
{
  "kubernetes_namespace": "app"	
}
EOT
}

resource "boundary_credential_library_vault" "cicd-write" {
  name                = "cicd-write"
  description         = "Vault Dynamic Kubernetes Secerets Engine"
  credential_store_id = boundary_credential_store_vault.vault-cred-store.id
  path                = "kubernetes/creds/cicd-write"
  http_method         = "POST"
  http_request_body   = <<EOT
{
  "kubernetes_namespace": "app"	
}
EOT
}

resource "boundary_credential_library_vault" "kubernetes-ca" {
  name                = "kubernetes-ca"
  description         = "Vault KV - Kubernetes CA"
  credential_store_id = boundary_credential_store_vault.vault-cred-store.id
  path                = "secret/data/k8s-cluster"
  http_method         = "GET"
}

resource "boundary_host_catalog_static" "kubernetes" {
  name        = "Kubernetes Clusters"
  description = "Host Catalog contains all production Kubernetes clusters!"
  scope_id    = boundary_scope.project.id
}

resource "boundary_host_static" "kubernetes" {
  name            = "Kubernetes API"
  description     = "Kubernetes API"
  address         = "kubernetes.default.svc"
  host_catalog_id = boundary_host_catalog_static.kubernetes.id
}

resource "boundary_host_set_static" "kubernetes" {
  host_catalog_id = boundary_host_catalog_static.kubernetes.id
  host_ids = [
    boundary_host_static.kubernetes.id,
  ]
}

resource "boundary_target" "kubernetes" {
  name         = "Kubernetes Production"
  description  = "Kubernetes Production Cluster"
  type         = "tcp"
  default_port = "443"
  scope_id     = boundary_scope.project.id
  host_source_ids = [
    boundary_host_set_static.kubernetes.id
  ]
  brokered_credential_source_ids = [
     boundary_credential_library_vault.cicd-write.id,
     boundary_credential_library_vault.kubernetes-ca.id,
  ]

  egress_worker_filter = "\"/tags/session_recording/0\" == \"true\""
  ingress_worker_filter = "\"/tags/session_recording/0\" == \"true\""
}

resource "vault_token" "boundary" {

  policies = ["boundary-controller", "kv-read"]
  renewable = true
  no_parent = true
  ttl = "48h"
  renew_min_lease = 43200
  renew_increment = 86400
  no_default_policy = true
  period = "2d"

  metadata = {
    "purpose" = "boundary-service-account"
  }
}

resource "boundary_credential_store_vault" "vault-cred-store" {
  name        = "HashiCorp Vault - Production"
  description = "HashiCorp Vault in the Production VPC "
  address     = "http://vault:8200"
  token       = vault_token.boundary.client_token
  scope_id    = boundary_scope.project.id
  worker_filter = "\"/tags/session_recording/0\" == \"true\""
}

