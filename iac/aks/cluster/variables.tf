variable "location" {
  description = "Azure region of the cluster."
  type        = string
  default     = "westeurope"
}

variable "state_resource_group_name" {
  description = "Resource group of the Terraform state storage account."
  type        = string
}

variable "state_storage_account_name" {
  description = "Storage account that holds the Terraform state."
  type        = string
}

variable "node_vm_size" {
  description = "VM size of the single node."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "monthly_budget" {
  description = "Monthly budget of the cluster resource group, in the billing currency."
  type        = number
  default     = 100
}

variable "budget_contact_email" {
  description = "Address that gets the budget alert."
  type        = string
}

variable "hostname" {
  description = "Public hostname of the app. Must be in the Cloudflare zone."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone that holds the hostname."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare token with DNS edit rights on the zone. Terraform writes the record; cert-manager uses it for DNS-01."
  type        = string
  sensitive   = true
}
