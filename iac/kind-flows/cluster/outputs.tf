output "context_name" {
  description = "kubectl context of the cluster."
  value       = kind_cluster.this.context_name
}

output "endpoint" {
  description = "Kubernetes API server URL."
  value       = kind_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "CA certificate of the API server."
  value       = kind_cluster.this.cluster_ca_certificate
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate of the cluster admin."
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key of the cluster admin."
  value       = kind_cluster.this.client_key
  sensitive   = true
}
