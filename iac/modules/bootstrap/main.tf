locals {
  argocd_namespace          = "argocd"
  argocd_chart_version      = "10.18.1"
  argocd_apps_chart_version = "2.0.8"
}

resource "helm_release" "cilium" {
  count = var.cilium == null ? 0 : 1

  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium.chart_version
  namespace  = "kube-system"
  values     = [var.cilium.values]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = local.argocd_chart_version
  namespace        = local.argocd_namespace
  create_namespace = true
  values           = [file("${path.module}/values/argocd.yaml")]

  set_sensitive = [
    {
      name  = "configs.credentialTemplates.git.url"
      value = var.git_credentials.url_prefix
    },
    {
      name  = "configs.credentialTemplates.git.username"
      value = var.git_credentials.username
    },
    {
      name  = "configs.credentialTemplates.git.password"
      value = var.git_credentials.password
    },
  ]

  depends_on = [helm_release.cilium]
}

resource "helm_release" "root_application" {
  name       = "root-application"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = local.argocd_apps_chart_version
  namespace  = local.argocd_namespace

  values = [yamlencode({
    applications = {
      root = {
        namespace = local.argocd_namespace
        project   = "default"
        source = {
          repoURL        = var.root_application.repo_url
          targetRevision = var.root_application.revision
          path           = "components"
          helm = {
            valueFiles = ["../clusters/${var.root_application.cluster}/components.yaml"]
            valuesObject = {
              repoURL    = var.root_application.repo_url
              revision   = var.root_application.revision
              appRepoURL = var.root_application.app_repo_url
            }
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = local.argocd_namespace
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
