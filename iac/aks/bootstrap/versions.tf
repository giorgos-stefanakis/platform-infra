terraform {
  required_version = ">= 1.9"

  # Filled in by `make aks-up` from the outputs of iac/state.
  backend "azurerm" {}

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
  }
}
