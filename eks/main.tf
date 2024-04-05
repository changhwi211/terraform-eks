terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16"
    }
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0.5"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-northeast-2"
}

resource "aws_vpc" "dev_vpc" {
  cidr_block = "172.20.167.0/24"
  tags = {
    Name = "dev-vpc"
  }
}

resource "aws_subnet" "dev_sbn_a" {
  vpc_id     = aws_vpc.dev_vpc.id
  availability_zone = "ap-northeast-2a"
  cidr_block = "172.20.167.128/27"

  tags = {
    Name = "dev-sbn-a"
  }
}

resource "aws_subnet" "dev_sbn_c" {
  vpc_id     = aws_vpc.dev_vpc.id
  availability_zone = "ap-northeast-2c"
  cidr_block = "172.20.167.160/27"

  tags = {
    Name = "dev-sbn-c"
  }
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "AmazonEKSNodeRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_cluster" "dev_eks" {
  name     = "dev-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version = "1.28"

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids = [aws_subnet.dev_sbn_a.id, aws_subnet.dev_sbn_c.id]
    endpoint_public_access = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

# resource "aws_eks_addon" "dev_eks_addon_vpc_cni" {
#   cluster_name                = aws_eks_cluster.dev_eks.name
#   addon_name                  = "vpc-cni"
#   addon_version               = "v1.18.0-eksbuild.1"
#   resolve_conflicts_on_update = "PRESERVE"
# }

# resource "aws_eks_addon" "dev_eks_addon_coredns" {
#   cluster_name                = aws_eks_cluster.dev_eks.name
#   addon_name                  = "coredns"
#   addon_version               = "v1.10.1-eksbuild.7"
#   resolve_conflicts_on_update = "PRESERVE"
# }

# resource "aws_eks_addon" "dev_eks_addon_kube_proxy" {
#   cluster_name                = aws_eks_cluster.dev_eks.name
#   addon_name                  = "kube-proxy"
#   addon_version               = "v1.28.6-eksbuild.2"
#   resolve_conflicts_on_update = "PRESERVE"
# }

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

/*
  EKS Node Group
*/
