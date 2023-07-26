# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "boundary_role" "global_anon_listing" {
  scope_id = boundary_scope.global.id
  grant_strings = [
    "id=*;type=auth-method;actions=list,authenticate",
    "id=*;type=scope;actions=*",
    "id={{account.id}};actions=read,change-password",
    "id=*;type=host-catalog;actions=*",
    "type=host-catalog;actions=list"
  ]
  principal_ids = ["u_anon"]
}

resource "boundary_role" "org_anon_listing" {
  scope_id = boundary_scope.org.id
  grant_strings = [
    "id=*;type=auth-method;actions=list,authenticate",
    "id=*;type=scope;actions=*",
    "id={{account.id}};actions=read,change-password",
    "id=*;type=host-catalog;actions=*",
    "type=host-catalog;actions=list"
  ]
  principal_ids = ["u_anon"]
}

resource "boundary_role" "org_admin" {
  scope_id       = "global"
  grant_scope_id = boundary_scope.org.id
  grant_strings  = ["id=*;type=*;actions=*"]
  principal_ids = concat(
    [for user in boundary_user.user : user.id],
    ["u_auth"]
  )
}

resource "boundary_role" "proj_admin" {
  scope_id       = boundary_scope.org.id
  grant_scope_id = boundary_scope.project.id
  grant_strings  = ["id=*;type=*;actions=*"]
  principal_ids = concat(
    [for user in boundary_user.user : user.id],
    ["u_auth"],
    [boundary_user.admin-user.id],
  )
}

resource "boundary_role" "proj_anon_listing" {
  scope_id       = boundary_scope.org.id
  grant_scope_id = boundary_scope.project.id
  grant_strings = [
    "id=*;type=auth-method;actions=list,authenticate",
    "id=*;type=scope;actions=*",
    "id={{account.id}};actions=read,change-password",
    "id=*;type=host-catalog;actions=*",
    "type=host-catalog;actions=list"
  ]
  principal_ids = ["u_anon"]
}
