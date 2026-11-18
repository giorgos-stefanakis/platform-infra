provider "azurerm" {
  features {}
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "shared" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = "tfstate"
    key                  = "shared.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  shared = data.terraform_remote_state.shared.outputs
}

resource "azurerm_resource_group" "aks" {
  name     = "rg-demo-aks"
  location = var.location
}

resource "azurerm_consumption_budget_resource_group" "aks" {
  name              = "budget-demo-aks"
  resource_group_id = azurerm_resource_group.aks.id
  amount            = var.monthly_budget
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.budget_contact_email]
  }

  lifecycle {
    # The start date is fixed at creation; timestamp() would change it on every plan.
    ignore_changes = [time_period]
  }
}

# Cluster

resource "azurerm_kubernetes_cluster" "demo" {
  name                      = "aks-demo"
  location                  = azurerm_resource_group.aks.location
  resource_group_name       = azurerm_resource_group.aks.name
  dns_prefix                = "aks-demo"
  sku_tier                  = "Free"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "system"
    vm_size    = var.node_vm_size
    node_count = 1
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
  }

  # On destroy the cluster, and with it the load balancer, goes before the IP it holds.
  depends_on = [azurerm_public_ip.ingress]
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = local.shared.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
}

# Ingress address and DNS

resource "azurerm_public_ip" "ingress" {
  name                = "pip-demo-ingress"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# The cluster's load balancer attaches the ingress IP from this resource group.
resource "azurerm_role_assignment" "cluster_network_contributor" {
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.demo.identity[0].principal_id
}

resource "cloudflare_dns_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = var.hostname
  type    = "A"
  content = azurerm_public_ip.ingress.ip_address
  ttl     = 300
  proxied = false
}

# Secrets

resource "azurerm_key_vault" "demo" {
  name                       = "kv-demo-${local.shared.name_suffix}"
  location                   = azurerm_resource_group.aks.location
  resource_group_name        = azurerm_resource_group.aks.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.demo.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "external_secrets_reader" {
  scope                = azurerm_key_vault.demo.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.shared.external_secrets_identity_principal_id
}

resource "random_password" "demo_api_key" {
  length  = 48
  special = false
}

resource "azurerm_key_vault_secret" "demo_api_key" {
  name         = "demo-api-key"
  value        = random_password.demo_api_key.result
  key_vault_id = azurerm_key_vault.demo.id

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "cloudflare_api_token" {
  name         = "cloudflare-api-token"
  value        = var.cloudflare_api_token
  key_vault_id = azurerm_key_vault.demo.id

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

# Object store

resource "azurerm_storage_account" "demo" {
  name                            = "stdemo${local.shared.name_suffix}"
  resource_group_name             = azurerm_resource_group.aks.name
  location                        = azurerm_resource_group.aks.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_id    = azurerm_storage_account.demo.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "app_blob_contributor" {
  scope                = azurerm_storage_container.uploads.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.shared.app_identity_principal_id
}

# Workload identity: the service accounts that may act as each identity

resource "azurerm_federated_identity_credential" "app" {
  for_each = toset(["api", "worker"])

  name                      = "demo-${each.key}"
  user_assigned_identity_id = local.shared.app_identity_id
  issuer                    = azurerm_kubernetes_cluster.demo.oidc_issuer_url
  subject                   = "system:serviceaccount:demo:${each.key}"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  name                      = "external-secrets"
  user_assigned_identity_id = local.shared.external_secrets_identity_id
  issuer                    = azurerm_kubernetes_cluster.demo.oidc_issuer_url
  subject                   = "system:serviceaccount:external-secrets:external-secrets"
  audience                  = ["api://AzureADTokenExchange"]
}
