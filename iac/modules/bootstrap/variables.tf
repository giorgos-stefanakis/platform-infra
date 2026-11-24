variable "cilium" {
  description = "Cilium chart version and values. Null skips Cilium, for clusters that bring their own CNI."
  type = object({
    chart_version = string
    values        = string
  })
  default = null
}

variable "git_credentials" {
  description = "Credential template Argo CD uses for every repository under the URL prefix."
  type = object({
    url_prefix = string
    username   = string
    password   = string
  })
  sensitive = true
}

variable "root_application" {
  description = <<-EOT
    Repository and revision of the root Application, the cluster whose component list it renders, the repository of
    the application chart, an optional directory of infrastructure the client cluster brings itself, and an optional
    directory of Argo CD objects in the client's own GitOps repository.
  EOT
  type = object({
    repo_url     = string
    revision     = string
    cluster      = string
    app_repo_url = string
    client_path  = optional(string)
    client_repo = optional(object({
      repo_url = string
      revision = string
      path     = string
    }))
  })
}
