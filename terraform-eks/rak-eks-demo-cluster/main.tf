###### root/main.tf

module "vpc" {
  source                                 = "./modules/vpc"
  vpc_name                               = var.vpc_name
  vpc_cidr_block                         = var.vpc_cidr_block
  vpc_public_subnets                     = var.vpc_public_subnets
  vpc_private_subnets                    = var.vpc_private_subnets
  vpc_database_subnets                   = var.vpc_database_subnets
  vpc_create_database_subnet_group       = var.vpc_create_database_subnet_group
  vpc_create_database_subnet_route_table = var.vpc_create_database_subnet_route_table
  vpc_enable_nat_gateway                 = var.vpc_enable_nat_gateway
  vpc_single_nat_gateway                 = var.vpc_single_nat_gateway
  common_tags                            = local.common_tags
  eks_cluster_name                       = local.eks_cluster_name
}

module "bastian_host" {
  source           = "./modules/bastion_host"
  name_prefix      = local.name
  instance_type    = var.instance_type
  instance_keypair = var.instance_keypair
  common_tags      = local.common_tags
  vpc_id           = module.vpc.vpc_id
  vpc_subnets      = module.vpc.public_subnets[0]
}