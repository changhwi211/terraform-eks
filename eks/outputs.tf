output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.dev_eks.name
}

# output "oidc_identity_provider_arn" {
#   description = "EKS OIDC Identity Provider ARN"
#   value       = aws_iam_openid_connect_provider.dev_eks_oidc_identity_provider.arn
# }

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.dev_eks.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.dev_eks.vpc_config[0].security_group_ids
}

output "region" {
  description = "AWS region"
  value       = "ap-northeast-2"
}
