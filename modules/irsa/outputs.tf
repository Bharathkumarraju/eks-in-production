output "service_account" {
  description = "Name of Kubernetes service account"
  value       = try(kubernetes_service_account_v1.irsa[0].metadata[0].name, null)
}
