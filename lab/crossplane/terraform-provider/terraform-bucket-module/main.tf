resource "random_string" "storage_bucket_id" {
  keepers = {
    prefix = var.prefix
  }

  length      = 3
  min_lower   = 1
  min_numeric = 2
  lower       = true
  special     = false
}

locals {
  storage_bucket_name = "${var.prefix}-${random_string.storage_bucket_id.result}"
}

resource "google_storage_bucket" "default" {
  name                        = local.storage_bucket_name
  location                    = var.location
  force_destroy               = true
  uniform_bucket_level_access = true
}
