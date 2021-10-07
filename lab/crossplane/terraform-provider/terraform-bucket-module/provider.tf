provider "google" {
  credentials = "gcp-credentials.json"
  project     = "sandbox-328317"
}

terraform {
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
