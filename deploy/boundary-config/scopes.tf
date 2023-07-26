# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "boundary_scope" "global" {
  global_scope = true
  name         = "global"
  scope_id     = "global"
}

resource "boundary_scope" "org" {
  scope_id    = boundary_scope.global.id
  name        = "HashiBank"
  description = "Primary organization scope"
}



resource "boundary_scope" "project" {
  name                     = "Cloud-Ops"
  description              = "Cloud-Ops Project"
  scope_id                 = boundary_scope.org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "project-1" {
  name                     = "IAM"
  description              = "IAM Project"
  scope_id                 = boundary_scope.org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "project-2" {
  name                     = "Platform Engineering"
  description              = "Platform Project"
  scope_id                 = boundary_scope.org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}
