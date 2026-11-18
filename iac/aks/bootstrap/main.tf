data "terraform_remote_state" "cluster" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = "tfstate"
    key                  = "aks-cluster.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  cluster = data.terraform_remote_state.cluster.outputs
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster.host
    cluster_ca_certificate = local.cluster.cluster_ca_certificate
    client_certificate     = local.cluster.client_certificate
    client_key             = local.cluster.client_key
  }
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  git_credentials = {
    url_prefix = "https://github.com/${var.github_owner}"
    username   = "git"
    password   = var.git_token
  }

  root_application = {
    repo_url     = "https://github.com/${var.github_owner}/platform-infra.git"
    revision     = var.git_revision
    cluster      = "aks"
    app_repo_url = "https://github.com/${var.github_owner}/demo-apps.git"
    client_path  = "clusters/aks/client"
  }
}
