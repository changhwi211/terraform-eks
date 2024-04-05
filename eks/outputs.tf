output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.dev_eks.name
}

# output "oidc_identity_provider_arn" {
#   description = "EKS OIDC Identity Provider ARN"
#   value       = aws_iam_openid_connect_provider.dev_eks_oidc_identity_provider.arn
# }