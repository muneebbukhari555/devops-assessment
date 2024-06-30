# Terraform Settings Block
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
  }
  ## Backend Remote State Storage.
  # backend "s3" {
  #   bucket = "rak-terraform-aws-eks"
  #   key    = "prod/rak-eks-demo.tfstate"
  #   region = "us-east-1"

  #   # For State Locking
  #   dynamodb_table = "prod-rakeksdemo"
  # }
  backend "s3" {}
}
# Terraform Provider Block
provider "aws" {
  region = var.aws_region
}