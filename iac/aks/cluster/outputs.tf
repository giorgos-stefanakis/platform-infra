output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.demo.name
}

output "resource_group_name" {
  description = "Resource group of the AKS cluster."
  value       = azurerm_resource_group.aks.name
}

output "host" {
  description = "Kubernetes API server URL."
  value       = azurerm_kubernetes_cluster.demo.kube_config[0].host
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "CA certificate of the API server, PEM."
  value       = base64decode(azurerm_kubernetes_cluster.demo.kube_config[0].cluster_ca_certificate)
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate of the cluster admin, PEM."
  value       = base64decode(azurerm_kubernetes_cluster.demo.kube_config[0].client_certificate)
  sensitive   = true
}

output "client_key" {
  description = "Client key of the cluster admin, PEM."
  value       = base64decode(azurerm_kubernetes_cluster.demo.kube_config[0].client_key)
  sensitive   = true
}

output "key_vault_url" {
  description = "Key Vault URL, for the ClusterSecretStore."
  value       = azurerm_key_vault.demo.vault_uri
}

output "blob_account_url" {
  description = "Blob endpoint of the storage account, for objectStore.azureblob.accountUrl."
  value       = azurerm_storage_account.demo.primary_blob_endpoint
}

output "ingress_ip" {
  description = "Static public IP of the ingress controller."
  value       = azurerm_public_ip.ingress.ip_address
}
