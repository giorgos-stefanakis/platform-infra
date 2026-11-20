locals {
  node_image = "kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed"

  # The gateway Service exposes this NodePort; the host reaches it on port 80.
  gateway_node_port = 30080
}

resource "kind_cluster" "this" {
  name       = var.cluster_name
  node_image = local.node_image

  # Without a path the provider also writes a kubeconfig with the admin key into this directory.
  kubeconfig_path = pathexpand("~/.kube/config")

  # The node stays NotReady until stage 2 installs Cilium.
  wait_for_ready = false

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      disable_default_cni = true
    }

    node {
      role = "control-plane"

      # kind taints the control plane once workers exist; three schedulable nodes let replicas spread.
      kubeadm_config_patches = [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          taints: []
        EOT
      ]

      extra_port_mappings {
        container_port = local.gateway_node_port
        host_port      = 80
      }
    }

    node {
      role = "worker"
    }

    node {
      role = "worker"
    }
  }
}
