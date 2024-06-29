# AWS EC2 Security Group Terraform Module
# Security Group for Public Bastion Host
module "public_bastion_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"  

  name = "${var.name_prefix}-public-bastion-sg"
  description = "Security Group with SSH port open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id = var.vpc_id
  # Ingress Rules & CIDR Blocks
  ingress_rules = var.bastion_ingress_port_rule
  ingress_cidr_blocks = var.bastion_ingress_CIDR
  # Egress Rule - all-all open
  egress_rules = ["all-all"]
  tags = var.common_tags
}