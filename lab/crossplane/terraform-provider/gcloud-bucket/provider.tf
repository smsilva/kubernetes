provider "google" {
  credentials = "credentials.json"
}

terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  backend "gcs" {
    credentials = "credentials.json"
    bucket      = "silvios-wasp-foundation-k9z"
    prefix      = "terraform"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.72.0"
    }
  }
}
