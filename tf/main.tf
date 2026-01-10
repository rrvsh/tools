terraform {
  backend "gcs" {
    bucket  = "rrvsh-tools-production-tfstate"
    prefix  = "terraform/state"
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

provider "google" {
  project = var.project_id
  region = "asia-southeast1"
  zone = "asia-southeast1-a"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
