provider "google" {
  credentials = "gcp-credentials.json"
}

terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.72.0"
    }
  }

  backend "gcs" {
    bucket      = "silvios-wasp-dev-foundation"
    prefix      = "terraform"
    credentials = "gcp-credentials.json"
  }
}
