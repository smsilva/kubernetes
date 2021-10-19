provider "google" {
  credentials = "credentials.json"
}

terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.72.0"
    }
  }
}
