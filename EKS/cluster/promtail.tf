module "promtail" {
  source = "../../modules/helm-addon"

  helm_config = {
    name        = "promtail"
    chart       = "promtail"
    repository  = "https://grafana.github.io/helm-charts"
    version     = "6.11.2"
    namespace   = kubernetes_namespace_v1.monitoring.metadata[0].name
    description = "Promtail is an agent which ships the contents of local logs to a Loki instance"
    set = [
      {
        name  = "config.clients[0].url"
        value = format("http://loki-distributed-gateway.%s.svc.cluster.local/loki/api/v1/push", kubernetes_namespace_v1.monitoring.metadata[0].name)
      },
      {
        name  = "resources.requests.cpu"
        value = "10m"
      },
      {
        name  = "resources.requests.memory"
        value = "64Mi"
      },
      {
        name  = "priorityClassName"
        value = "system-cluster-critical"
      }
    ]
  }
  depends_on = [
    module.loki
  ]
}
