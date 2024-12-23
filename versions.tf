terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }
  }
}

provider "aws" {
  shared_config_files      = var.config_file
  shared_credentials_files = var.creds_file
  profile                  = var.aws_profile
  region                   = var.aws_region
}
