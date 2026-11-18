variable "state_resource_group_name" {
  description = "Resource group of the Terraform state storage account."
  type        = string
}

variable "state_storage_account_name" {
  description = "Storage account that holds the Terraform state."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organisation that owns the platform-infra and demo-apps repositories."
  type        = string
  default     = "giorgos-stefanakis"
}

variable "git_token" {
  description = "GitHub token with read access to both repositories, for example from `gh auth token`."
  type        = string
  sensitive   = true
}

variable "git_revision" {
  description = "Branch, tag or commit of platform-infra that Argo CD syncs."
  type        = string
  default     = "main"
}
