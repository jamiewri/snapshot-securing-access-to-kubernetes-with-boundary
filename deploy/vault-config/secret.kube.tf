resource "vault_kubernetes_secret_backend" "config" {
  path                      = "kubernetes"
  description               = "kubernetes secrets engine description"
  default_lease_ttl_seconds = 43200
  max_lease_ttl_seconds     = 86400
  disable_local_ca_jwt      = false
}

resource "vault_kubernetes_secret_backend_role" "cicd-write" {
  backend                       = vault_kubernetes_secret_backend.config.path
  name                          = "cicd-write"
  allowed_kubernetes_namespaces = ["*"]
  token_max_ttl                 = 43200
  token_default_ttl             = 600
  kubernetes_role_type          = "Role"
  generated_role_rules          = <<EOF
rules:
- apiGroups: [""]
  resources: ["pods", "deployments", "services"]
  verbs: ["get", "create", "update", "list", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list"]
EOF
}

resource "vault_kubernetes_secret_backend_role" "read-only" {
  backend                       = vault_kubernetes_secret_backend.config.path
  name                          = "read-only"
  allowed_kubernetes_namespaces = ["*"]
  token_max_ttl                 = 43200
  token_default_ttl             = 600
  kubernetes_role_type          = "Role"
  generated_role_rules          = <<EOF
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "describe"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles"]
  verbs: ["get", "list", "describe"]
EOF
}

