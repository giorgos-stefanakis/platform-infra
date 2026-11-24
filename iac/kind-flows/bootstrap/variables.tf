variable "github_owner" {
  description = "GitHub user or organisation that owns the platform-infra and client GitOps repositories."
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

variable "client_repository" {
  description = "Name of the client's GitOps repository."
  type        = string
  default     = "client-acme-gitops"
}

variable "client_revision" {
  description = "Branch, tag or commit of the client's GitOps repository that Argo CD syncs."
  type        = string
  default     = "main"
}
