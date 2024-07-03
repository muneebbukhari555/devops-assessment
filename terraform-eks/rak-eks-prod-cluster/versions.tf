# Terraform Settings Block
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
  }
  backend "s3" {}
}
# Terraform Provider Block
provider "aws" {
  region = var.aws_region
}
provider "http" {
  # Configuration options 
}