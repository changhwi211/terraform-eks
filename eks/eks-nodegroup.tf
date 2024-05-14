resource "aws_eks_node_group" "dev_eksng" {
  cluster_name    = aws_eks_cluster.dev_eks.name
  node_group_name = "dev_eksng"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = module.vpc.private_subnets

  launch_template {
    id      = aws_launch_template.dev_lt_eksng.id
    version = aws_launch_template.dev_lt_eksng.default_version
  }

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  # depends_on = [
  #   aws_iam_role_policy_attachment.eks_worker_node_policy,
  #   aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  #   aws_iam_role_policy_attachment.eks_cni_policy,
  # ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "AmazonEKSNodeRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
}

resource "aws_launch_template" "dev_lt_eksng" {
  name                   = "dev_lt_eksng"
  instance_type          = "t3a.medium"
  key_name               = aws_key_pair.dev_kp_eksng.key_name
  vpc_security_group_ids = [aws_security_group.dev_sg_eksng.id]

  # default_version = 2
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
    }
  }
}

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
