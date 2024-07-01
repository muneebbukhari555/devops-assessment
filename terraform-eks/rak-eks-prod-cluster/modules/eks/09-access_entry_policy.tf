# Access Entry Configurations for an EKS Cluster.
resource "aws_eks_access_entry" "eks_cluster" {
  depends_on        = [aws_eks_cluster.eks_cluster, aws_iam_role.github_actions_role]
  cluster_name      = aws_eks_cluster.eks_cluster.name
  principal_arn     = aws_iam_role.github_actions_role.arn
  type              = "STANDARD"
}

# Access Entry Policy Association for an EKS Cluster.
resource "aws_eks_access_policy_association" "eks_cluster" {
  depends_on    = [aws_eks_cluster.eks_cluster, aws_iam_role.github_actions_role]
  cluster_name  = aws_eks_cluster.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.github_actions_role.arn

  access_scope {
    type       = "cluster"
  }
}