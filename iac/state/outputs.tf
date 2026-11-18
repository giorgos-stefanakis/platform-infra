output "resource_group_name" {
  description = "Resource group of the state storage account."
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Storage account that holds the Terraform state of the other stages."
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Blob container that holds the state files."
  value       = azurerm_storage_container.state.name
}
