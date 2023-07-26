provider "boundary" {
  addr = var.BOUNDARY_ADDR
  recovery_kms_hcl = <<EOT
kms "aead" {
  purpose = "recovery"
  aead_type = "aes-gcm"
  key_id = "global_recovery"
  key = "Ivj8Si8UQBp+Zm2lLbUDTxOGikE8rSo6QihCjWSTXqY="
}
EOT
}

variable "BOUNDARY_ADDR" {}

terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.8"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.17.0"
    }
  }
  backend "local" {}
}

variable "VAULT_ADDR" {}
provider "vault" {
  address = var.VAULT_ADDR
}
