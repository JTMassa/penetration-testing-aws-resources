# Defines the Terraform and provider versions required by this project.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configures AWS provider access and applies common tags to all resources.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}