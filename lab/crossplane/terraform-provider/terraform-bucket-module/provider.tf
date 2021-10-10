provider "google" {
  credentials = "gcp-credentials.json"
  project     = "sandbox-328317"
}

terraform {
  required_version = ">= 1.0.5, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.72.0"
    }
  }

  backend "gcs" {
    bucket      = "silvios"
    prefix      = "terraform/crossplane"
    credentials = "gcp-credentials.json"
  }
}
