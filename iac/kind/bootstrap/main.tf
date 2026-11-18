data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = "${path.module}/../cluster/terraform.tfstate"
  }
}

locals {
  cluster = data.terraform_remote_state.cluster.outputs
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster.endpoint
    cluster_ca_certificate = local.cluster.cluster_ca_certificate
    client_certificate     = local.cluster.client_certificate
    client_key             = local.cluster.client_key
  }
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  cilium = {
    chart_version = "1.20.5"
    values        = file("${path.module}/cilium.yaml")
  }

  git_credentials = {
    url_prefix = "https://github.com/${var.github_owner}"
    username   = "git"
    password   = var.git_token
  }

  root_application = {
    repo_url = "https://github.com/${var.github_owner}/platform-infra.git"
    revision = var.git_revision
    cluster  = "kind"
  }
}
