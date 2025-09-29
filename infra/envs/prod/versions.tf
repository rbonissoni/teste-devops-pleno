terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Preencha com os valores reais do backend remoto:
    bucket         = "renan-bonissoni-terraform"
    key            = "envs/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-lock-table"
  }
}

provider "aws" {
  region = var.region
}
