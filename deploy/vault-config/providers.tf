variable "VAULT_ADDR" {}
provider "vault" {
  address = var.VAULT_ADDR
}

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.17.0"
    }
  }
  backend "local" {}
}
