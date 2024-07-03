provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "github_actions_role" {
  name = var.github_access_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.repository_name}"
          }
          StringEqualsIgnoreCase = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
            AWS = var.cluster_admin_user_arn 
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name   = "OidcSafetyPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "OidcSafeties"
          Effect = "Deny"
          Action = "sts:AssumeRole"
          Resource = "*"
        }
      ]
    })
  }

  inline_policy {
    name   = "GitHubActionsECRPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "AllowPushPull"
          Effect = "Allow"
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:GetAuthorizationToken"
          ]
          Resource = "*"
        },
        {
          Sid    = "AllowEKSClusterAccess"
          Effect = "Allow"
          Action = "eks:DescribeCluster"
          Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${var.cluster_name}"
        }
      ]
    })
  }
}

data "aws_caller_identity" "current" {}
