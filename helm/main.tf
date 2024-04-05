terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.8.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.17.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.52.0"
    }
  }
  required_version = "~> 1.3"
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "eks" {
  backend = "local"
  config = {
    path = "../eks/terraform.tfstate"
  }
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
      command     = "aws"
    }
  }
}

/*
  AWS Load Balancer Controller
*/

data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_policy" "aws_load_balancer_controller_iam_policy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/iam_policy.json")
}

locals {
  dev_eks_oidc_identity_provider = join("/", slice(split("/", data.aws_iam_openid_connect_provider.cluster.arn), 1, 4))
}

data "aws_iam_policy_document" "load_balancer_role_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

     principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.cluster.arn]
    }

    condition {
      test = "StringEquals"
      variable = format("%s:%s", local.dev_eks_oidc_identity_provider, "aud")
      values = ["sts.amazonaws.com"]
    }

    condition {
      test = "StringEquals"
      variable = format("%s:%s", local.dev_eks_oidc_identity_provider, "sub")
      values = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "amazon_eks_load_balancer_controller_role" {
  name                = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy  = data.aws_iam_policy_document.load_balancer_role_trust_policy.json
  managed_policy_arns = [aws_iam_policy.aws_load_balancer_controller_iam_policy.arn]
}

resource "kubernetes_manifest" "aws_load_balancer_controller_service_account" {
  manifest = templatefile("${path.module}/aws-load-balancer-controller-service-account.yaml", {AWS_IAM_ROLE_ARN = aws_iam_role.amazon_eks_load_balancer_controller_role.arn})
}