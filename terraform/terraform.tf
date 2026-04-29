terraform {
  backend "s3" {
    key    = "backend/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.37.0"
    }
  }

  required_version = "~> 1.14.8"
}

provider "aws" {
  region = "us-east-1"
}