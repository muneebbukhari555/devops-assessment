# Generic Variables
aws_region       = "us-east-1"
environment      = "prod"
business_divsion = "rak"
aws_account_id   = ""

### VPC Details
vpc_name                               = "vpc"
vpc_cidr_block                         = "10.0.0.0/16"
vpc_public_subnets                     = ["10.0.101.0/24", "10.0.102.0/24"]
vpc_private_subnets                    = ["10.0.1.0/24", "10.0.2.0/24"]
vpc_database_subnets                   = ["10.0.151.0/24", "10.0.152.0/24"]
vpc_create_database_subnet_group       = true
vpc_create_database_subnet_route_table = true
vpc_enable_nat_gateway                 = true
vpc_single_nat_gateway                 = true

### Bastion Host
instance_type    = "t2.medium"
instance_keypair = "eks-terraform-key"

### EKS Cluster
cluster_name                    = "eksdemo"
cluster_service_ipv4_cidr       = "172.20.0.0/16"
cluster_version                 = "1.29"
cluster_endpoint_private_access = true
ng_instance_type                = ["t3.medium"]
ng_ami_type                     = "AL2_x86_64"
ng_disk_size                    = 20
scaling_desired_size            = 1
scaling_min_size                = 1
scaling_max_size                = 2
aws_ecr_repository              = "java-web-app"
repository_name                 = "muneebbukhari555/*"
github_access_role_name         = "GitHub_Actions_CICD_Role"
cluster_admin_user_arn          = "" #Use for Admin access for EKS Cluster
