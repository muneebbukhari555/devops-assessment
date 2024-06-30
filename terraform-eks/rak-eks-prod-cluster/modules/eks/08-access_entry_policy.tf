# Access Entry Configurations for an EKS Cluster.
resource "aws_eks_access_entry" "eks_cluster" {
  cluster_name      = var.cluster_name
  principal_arn     = var.k8s_access_role
  type              = "STANDARD"
}

# Access Entry Policy Association for an EKS Cluster.
resource "aws_eks_access_policy_association" "eks_cluster" {
  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = var.k8s_access_role

  access_scope {
    type       = "cluster"
  }
}