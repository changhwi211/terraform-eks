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
      source  = "hashicorp/local"
      version = "~> 2.5.1"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-northeast-2"
}

/*
  VPC Endpoint
*/
# resource "aws_security_group" "dev_dev_sg_vpc_ep_eks" {
#   name = "dev_dev_sg_vpc_ep_eks"
#   vpc_id = aws_vpc.dev_vpc.id
# }

# resource "aws_vpc_security_group_ingress_rule" "vpc_ep_eks_allow_eks_nodes" {
#   security_group_id = aws_security_group.dev_dev_sg_vpc_ep_eks.id
#   ip_protocol = "TCP"
#   from_port = 443
#   to_port = 443
#   referenced_security_group_id = aws_security_group.dev_sg_eksng.id
#   description = "eks nodes"
# }

# resource "aws_vpc_security_group_egress_rule" "vpc_ep_eks_allow_control_plane" {
#   security_group_id = aws_security_group.dev_dev_sg_vpc_ep_eks.id
#   ip_protocol = "TCP"
#   from_port = 443
#   to_port = 443
#   referenced_security_group_id = aws_eks_cluster.dev_eks.vpc_config[0].cluster_security_group_id
# }

# resource "aws_vpc_endpoint" "dev_vpc_ep_eks" {
#   vpc_id = aws_vpc.dev_vpc.id
#   service_name = "com.amazonaws.ap-northeast-2.eks"
#   vpc_endpoint_type = "Interface"

#   security_group_ids = [
#     aws_security_group.dev_dev_sg_vpc_ep_eks.id,
#   ]

#   subnet_ids = [aws_subnet.dev_sbn_pri_a.id, aws_subnet.dev_sbn_pri_c.id]

#   private_dns_enabled = true
# }