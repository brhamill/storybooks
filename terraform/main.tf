terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 3.38"
    }
    mongodbatlas = {
      source = "mongodb/mongodbatlas"
      version = "~> 1.0"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
  backend "gcs" {
    bucket = "devops-dtg-storybooks-terraform"
    prefix = "/state/storybooks"
  }
}