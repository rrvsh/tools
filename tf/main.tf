terraform {
  backend "gcs" {
    bucket  = "rrvsh-tools-production-tfstate"
    prefix  = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region = "asia-southeast1"
  zone = "asia-southeast1-a"
}
