# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "boundary_account_password" "user" {
  for_each       = var.users
  name           = lower(each.key)
  description    = "Account password for ${each.key}"
  auth_method_id = boundary_auth_method_password.password.id
  login_name     = lower(each.key)
  password       = "password123"
}
