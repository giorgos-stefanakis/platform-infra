provider "azurerm" {
  features {}
}

provider "azuread" {}

data "azuread_client_config" "current" {}

locals {
  # Microsoft's public client ID of the Azure CLI. Pre-authorising it lets the smoke test get an api token with
  # `az account get-access-token`, without a browser.
  azure_cli_client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
}

# Suffix for names that must be globally unique.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-demo-shared"
  location = var.location
}

# The registry and the identities outlive the AKS cluster, so the image reference and the client IDs in the
# cluster values stay the same across aks-down and aks-up.
resource "azurerm_container_registry" "demo" {
  name                = "crdemo${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Clusters outside Azure pull the image with this token. It can only read the demo-app repository.
resource "azurerm_container_registry_scope_map" "pull" {
  name                    = "demo-app-pull"
  container_registry_name = azurerm_container_registry.demo.name
  resource_group_name     = azurerm_resource_group.shared.name
  actions                 = ["repositories/demo-app/content/read"]
}

resource "azurerm_container_registry_token" "pull" {
  name                    = "demo-app-pull"
  container_registry_name = azurerm_container_registry.demo.name
  resource_group_name     = azurerm_resource_group.shared.name
  scope_map_id            = azurerm_container_registry_scope_map.pull.id
}

resource "azurerm_container_registry_token_password" "pull" {
  container_registry_token_id = azurerm_container_registry_token.pull.id

  password1 {}
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-demo-app"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
}

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "id-demo-external-secrets"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
}

resource "random_uuid" "access_as_user_scope" {}

resource "azuread_application" "demo" {
  display_name     = "demo-app"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]

  single_page_application {
    redirect_uris = ["http://localhost/", "https://${var.aks_hostname}/"]
  }

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      id                         = random_uuid.access_as_user_scope.result
      value                      = "access_as_user"
      type                       = "User"
      enabled                    = true
      admin_consent_display_name = "Use the demo app"
      admin_consent_description  = "Lets the demo page call the demo api as the signed-in user."
      user_consent_display_name  = "Use the demo app"
      user_consent_description   = "Lets the demo page call the demo api as you."
    }
  }

  lifecycle {
    # Managed by azuread_application_identifier_uri, which needs the client ID first.
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_application_identifier_uri" "demo" {
  application_id = azuread_application.demo.id
  identifier_uri = "api://${azuread_application.demo.client_id}"
}

resource "azuread_service_principal" "demo" {
  client_id = azuread_application.demo.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_pre_authorized" "azure_cli" {
  application_id       = azuread_application.demo.id
  authorized_client_id = local.azure_cli_client_id
  permission_ids       = [random_uuid.access_as_user_scope.result]
}
