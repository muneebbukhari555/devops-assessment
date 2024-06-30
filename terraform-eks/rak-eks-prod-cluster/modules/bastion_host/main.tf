# AWS EC2 Instance Terraform Module
# Bastion Host - EC2 Instance that will be created in VPC Public Subnet
module "ec2_public" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.5.0"
  # insert the required variables here
  name          = "${var.name_prefix}-BastionHost"
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.instance_keypair
  subnet_id              = var.vpc_subnets
  vpc_security_group_ids = [module.public_bastion_sg.security_group_id]
  tags                   = var.common_tags
}