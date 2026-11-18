variable "location" {
  description = "Azure region of the shared resources."
  type        = string
  default     = "westeurope"
}

variable "aks_hostname" {
  description = "Public hostname of the app on AKS, for the sign-in redirect URI."
  type        = string
}
