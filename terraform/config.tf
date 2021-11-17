terraform {
  required_version = "= 1.0.6"

  backend "s3" {
    encrypt = true
    bucket  = "terraform-remote-state-kubeadm"
    key     = "terraform.tfstate"
    region  = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}
