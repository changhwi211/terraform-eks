module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "dev_vpc"

  cidr                 = "172.20.167.0/24"
  azs                  = ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnets      = ["172.20.167.128/27", "172.20.167.160/27"]
  private_subnet_names = ["dev-sbn-pri-a", "dev-sbn-pri-c"]
  public_subnets       = ["172.20.167.64/27", "172.20.167.96/27"]
  public_subnet_names  = ["dev-sbn-pub-a", "dev-sbn-pub-c"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  create_igw = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" : "1",
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" : "1",
  }
}
