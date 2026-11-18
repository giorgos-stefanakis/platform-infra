output "name_suffix" {
  description = "Suffix of the globally unique resource names."
  value       = random_string.suffix.result
}

output "resource_group_name" {
  description = "Resource group of the shared resources."
  value       = azurerm_resource_group.shared.name
}

output "acr_id" {
  description = "Resource ID of the container registry."
  value       = azurerm_container_registry.demo.id
}

output "acr_login_server" {
  description = "Login server of the container registry; the image repository is <login server>/demo-app."
  value       = azurerm_container_registry.demo.login_server
}

output "app_identity_id" {
  description = "Resource ID of the app pods' managed identity."
  value       = azurerm_user_assigned_identity.app.id
}

output "app_identity_client_id" {
  description = "Client ID of the app pods' managed identity, for workloadIdentity.clientId."
  value       = azurerm_user_assigned_identity.app.client_id
}

output "app_identity_principal_id" {
  description = "Principal ID of the app pods' managed identity, for role assignments."
  value       = azurerm_user_assigned_identity.app.principal_id
}

output "external_secrets_identity_id" {
  description = "Resource ID of the External Secrets Operator identity."
  value       = azurerm_user_assigned_identity.external_secrets.id
}

output "external_secrets_identity_client_id" {
  description = "Client ID of the External Secrets Operator identity."
  value       = azurerm_user_assigned_identity.external_secrets.client_id
}

output "external_secrets_identity_principal_id" {
  description = "Principal ID of the External Secrets Operator identity, for role assignments."
  value       = azurerm_user_assigned_identity.external_secrets.principal_id
}

output "auth_tenant_id" {
  description = "Entra ID tenant, for auth.tenantId."
  value       = data.azuread_client_config.current.tenant_id
}

output "auth_client_id" {
  description = "Client ID of the app registration, for auth.clientId."
  value       = azuread_application.demo.client_id
}

output "auth_api_audience" {
  description = "App ID URI of the api, for auth.apiAudience."
  value       = azuread_application_identifier_uri.demo.identifier_uri
}
