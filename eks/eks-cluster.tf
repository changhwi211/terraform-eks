resource "aws_eks_cluster" "dev_eks" {
  name     = "dev-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.28"

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids             = module.vpc.private_subnets
    endpoint_public_access = true
    security_group_ids     = [aws_security_group.dev_sg_ekscp.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  # depends_on = [
  #   aws_iam_role_policy_attachment.eks_cluster_policy,
  # ]
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  ]
}

/*
  EKS Add-on
*/

resource "aws_eks_addon" "dev_eks_addon_vpc_cni" {
  cluster_name                = aws_eks_cluster.dev_eks.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.18.0-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "dev_eks_addon_coredns" {
  cluster_name                = aws_eks_cluster.dev_eks.name
  addon_name                  = "coredns"
  addon_version               = "v1.10.1-eksbuild.7"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "dev_eks_addon_kube_proxy" {
  cluster_name                = aws_eks_cluster.dev_eks.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.28.6-eksbuild.2"
  resolve_conflicts_on_update = "OVERWRITE"
}

/*
  EKS OIDC Identity Providers
*/

data "tls_certificate" "dev_eks_oidc_tls_certificate" {
  url = aws_eks_cluster.dev_eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "dev_eks_oidc_identity_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.dev_eks_oidc_tls_certificate.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.dev_eks.identity[0].oidc[0].issuer
}
