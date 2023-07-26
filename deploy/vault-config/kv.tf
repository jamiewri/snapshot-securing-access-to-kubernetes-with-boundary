variable "ca_crt" {
  type = string
}

resource "vault_kv_secret_v2" "kubernetes_ca" {
  mount                      = "/secret"
  name                       = "k8s-cluster"
  cas                        = 1
  delete_all_versions        = true
  data_json                  = jsonencode(
  {
    ca_crt              = var.ca_crt
  }
  )
}
