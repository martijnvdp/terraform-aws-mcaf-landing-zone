locals {
  email               = var.email != null ? var.email : "${local.prefixed_email}@schubergphilis.com"
  name                = var.environment != null ? "${var.name}-${var.environment}" : var.name
  prefixed_email      = "${var.defaults.account_prefix}-aws-${local.name}"
  prefixed_name       = "${var.defaults.account_prefix}-${local.name}"
  organizational_unit = var.organizational_unit != null ? var.organizational_unit : var.environment == "prod" ? "Production" : "Non-Production"

  tags = {
    environment = var.environment != null ? var.environment : var.organizational_unit
    stack       = var.name
    terraform   = true
  }
}

module "account" {
  source                   = "github.com/schubergphilis/terraform-aws-mcaf-account?ref=v0.3.0"
  account                  = local.name
  email                    = local.email
  organizational_unit      = local.organizational_unit
  provisioned_product_name = var.provisioned_product_name
  sso_email                = var.defaults.sso_email
  sso_firstname            = var.sso_firstname
  sso_lastname             = var.sso_lastname
}

provider "aws" {
  alias  = "managed_by_inception"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.account.id}:role/AWSControlTowerExecution"
  }
}

resource "aws_iam_account_alias" "alias" {
  provider      = aws.managed_by_inception
  account_alias = local.prefixed_name
}

module "workspace" {
  source                 = "github.com/schubergphilis/terraform-aws-mcaf-workspace?ref=v0.2.2"
  providers              = { aws = aws.managed_by_inception }
  name                   = local.name
  auto_apply             = var.terraform_auto_apply
  branch                 = var.tfe_vcs_branch
  create_repository      = false
  github_organization    = var.defaults.github_organization
  github_repository      = var.name
  kms_key_id             = var.kms_key_id
  oauth_token_id         = var.oauth_token_id
  policy_arns            = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  region                 = var.region
  terraform_organization = var.defaults.terraform_organization
  terraform_version      = var.terraform_version != null ? var.terraform_version : var.defaults.terraform_version
  trigger_prefixes       = var.trigger_prefixes
  username               = "TFEPipeline"
  working_directory      = var.environment != null ? "terraform/${var.environment}" : "terraform"
  tags                   = local.tags
}