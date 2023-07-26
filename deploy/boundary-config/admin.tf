resource "boundary_role" "org_admin_role" {
  scope_id       = "global"
  grant_scope_id = boundary_scope.global.id
  grant_strings = [
    "id=*;type=*;actions=*"
  ]
  principal_ids = [boundary_user.admin-user.id]
}

resource "boundary_auth_method_password" "admin-password" {
  name        = "org_admin_password_auth"
  description = "Password auth method for global org"
  scope_id    = boundary_scope.global.id
}

resource "boundary_user" "admin-user" {
  name        = "admin-user"
  description = "User resource for admin-user"
  account_ids = [boundary_account_password.admin-user.id]
  scope_id    = boundary_scope.global.id
}

resource "boundary_account_password" "admin-user" {
  name           = "admin-user"
  description    = "Account password for admin-user"
  auth_method_id = boundary_auth_method_password.admin-password.id
  login_name     = "admin-user"
  password       = "password123"
}
