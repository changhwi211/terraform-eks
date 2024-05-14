resource "aws_security_group" "dev_sg_ekscp" {
  name   = "dev_sg_ekscp"
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_dev_eksng" {
  security_group_id = aws_security_group.dev_sg_ekscp.id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443

  referenced_security_group_id = aws_security_group.dev_sg_eksng.id
  description                  = "allow dev_eksng"
}

resource "aws_vpc_security_group_egress_rule" "dev_sg_ekscp_allow_all" {
  security_group_id = aws_security_group.dev_sg_ekscp.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "dev_sg_eksng" {
  name   = "dev_sg_eksng"
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_eks_control_plane" {
  security_group_id            = aws_security_group.dev_sg_eksng.id
  ip_protocol                  = -1
  referenced_security_group_id = aws_eks_cluster.dev_eks.vpc_config[0].cluster_security_group_id
  description                  = "eks control plane"
}

resource "aws_vpc_security_group_ingress_rule" "allow_eks_nodes" {
  security_group_id            = aws_security_group.dev_sg_eksng.id
  ip_protocol                  = -1
  referenced_security_group_id = aws_security_group.dev_sg_eksng.id
  description                  = "eks nodes"
}

resource "aws_vpc_security_group_egress_rule" "dev_sg_eksng_allow_all" {
  security_group_id = aws_security_group.dev_sg_eksng.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}