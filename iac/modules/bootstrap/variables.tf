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
  description = "Repository and revision of the root Application, and the cluster whose component list it renders."
  type = object({
    repo_url = string
    revision = string
    cluster  = string
  })
}
