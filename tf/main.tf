terraform {
  required_version = "~> 1.11"
  backend "s3" {
    bucket = "rrvsh-tfstate-dev"
    key = "tfstate/terraform.tfstate"
    region = "ap-southeast-1"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}
