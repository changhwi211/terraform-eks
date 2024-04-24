terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.5.1"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_vpc" "dev_vpc" {
  cidr_block = "172.20.167.0/24"
  enable_dns_hostnames = true
  tags = {
    Name = "dev-vpc"
  }
}

resource "aws_subnet" "dev_sbn_a" {
  vpc_id            = aws_vpc.dev_vpc.id
  availability_zone = "ap-northeast-2a"
  cidr_block        = "172.20.167.128/27"

  tags = {
    Name = "dev-sbn-a"
  }
}

resource "aws_subnet" "dev_sbn_c" {
  vpc_id            = aws_vpc.dev_vpc.id
  availability_zone = "ap-northeast-2c"
  cidr_block        = "172.20.167.160/27"

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
  version  = "1.28"

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids             = [aws_subnet.dev_sbn_a.id, aws_subnet.dev_sbn_c.id]
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
resource "tls_private_key" "dev_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "dev_kp_eksng" {
  key_name   = "dev_kp_eksng"
  public_key = tls_private_key.dev_key.public_key_openssh
}

resource "local_file" "dev_key_file" {
  filename        = "${path.module}/keypairs/dev_kp.pem"
  content         = tls_private_key.dev_key.private_key_pem
  file_permission = "0600"
}

resource "aws_security_group" "dev_sg_eksng" {
  name = "dev_sg_eksng"
  vpc_id = aws_vpc.dev_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_eks_control_plane" {
  security_group_id = aws_security_group.dev_sg_eksng.id
  ip_protocol = -1
  referenced_security_group_id = aws_eks_cluster.dev_eks.vpc_config[0].cluster_security_group_id
  description = "eks control plane"
}

resource "aws_vpc_security_group_ingress_rule" "allow_eks_nodes" {
  security_group_id = aws_security_group.dev_sg_eksng.id
  ip_protocol = -1
  referenced_security_group_id = aws_security_group.dev_sg_eksng.id
  description = "eks nodes"
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.dev_sg_eksng.id
  ip_protocol = -1
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_launch_template" "dev_lt_eksng" {
  name          = "dev_lt_eksng"
  instance_type = "t3a.medium"
  key_name      = aws_key_pair.dev_kp_eksng.key_name
  vpc_security_group_ids = [aws_security_group.dev_sg_eksng.id]
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
    }
  }
}

# resource "aws_eks_node_group" "dev_eksng" {
#   cluster_name = aws_eks_cluster.dev_eks.name
#   node_group_name = "dev_eksng"
#   node_role_arn = aws_iam_role.eks_node_role.arn
#   subnet_ids = [aws_subnet.dev_sbn_a.id, aws_subnet.dev_sbn_c.id]

#   scaling_config {
#     desired_size = 1
#     max_size = 3
#     min_size = 0
#   }

#   update_config {
#     max_unavailable = 1
#   }

#   depends_on = [ 
#     aws_iam_role_policy_attachment.eks_worker_node_policy,
#     aws_iam_role_policy_attachment.ec2_container_registry_read_only,
#     aws_iam_role_policy_attachment.eks_cni_policy,
#    ]

#    lifecycle {
#     ignore_changes = [scaling_config[0].desired_size]
#   }
# }