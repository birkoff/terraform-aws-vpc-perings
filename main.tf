terraform {
  required_version = ">= 0.12.1"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "MyOrg"

    workspaces {
      name = "vpc-peerings"
    }
  }
}

# VPC maigh be in different accounts
data "terraform_remote_state" "accounts" {
  backend = "remote"

  config = {
    organization = "MyOrg"

    workspaces = {
      name = "organisation-accounts"
    }
  }
}

locals {
  account_ids      = "${tomap(data.terraform_remote_state.accounts.outputs.account_ids)}"
  vpc_regions      = "${tomap(data.terraform_remote_state.accounts.outputs.vpc_regions)}"
  vpc_peering_ids  = "${tomap(data.terraform_remote_state.variables.outputs.vpc_peering_ids)}"
}

data "terraform_remote_state" "network" {
  backend = "remote"

  config = {
    organization = "MyOrg"

    workspaces = {
      name = "local-account-networking"
    }
  }
}

provider "aws" {
  region = "${lookup(local.vpc_regions, var.region_name)}"

  assume_role {
    role_arn = "arn:aws:iam::${lookup(local.account_ids, var.account_name)}:role/${var.assume_role}"
  }
}

