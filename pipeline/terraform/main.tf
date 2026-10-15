# Terraform Infrastructure as Code for NovaPay Digital Bank
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
  backend "s3" {
    bucket         = "novapay-terraform-state-prod"
    key            = "platform/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "novapay-tflocks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Bank        = "NovaPay"
      Environment = var.environment
      Compliance  = "RBI-Master-Direction-2023"
      ManagedBy   = "Terraform"
    }
  }
}
