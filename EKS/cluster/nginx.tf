resource "kubernetes_namespace_v1" "ingress-nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

module "ingress-nginx" {
  source = "../../modules/helm-addon"

  helm_config = {
    name        = "ingress-nginx"
    chart       = "ingress-nginx"
    repository  = "https://kubernetes.github.io/ingress-nginx"
    version     = "4.7.1"
    namespace   = kubernetes_namespace_v1.ingress-nginx.metadata[0].name
    description = "Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer"
    values = [
      file("config/ingress-nginx.yaml")
    ]
  }
  depends_on = [
    module.aws_load_balancer_controller
  ]
}
