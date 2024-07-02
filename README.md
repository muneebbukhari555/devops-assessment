# Devops-Assessment

---
Deploying a Java Application to AWS EKS using GitHub Actions and IAC with Terraform
---

## Introduction
 In this Repo, we’ll guide you through creating a GitHub action that accomplishes several key tasks: 
 1. Provision Amazon EKS Cluster with Private endpoint
 2. Building a Docker image, pushing it to the Amazon Elastic Container Registry (ECR), and ultimately deploying it to an Amazon Elastic Kubernetes Service (EKS) cluster.

We’ll break down each step in this tutorial.


1. Use Cloud Formation Stack to create Pre-requisites for Terraform EKS Provisioning e.g Bitbucket, Github OIDc, IAM Role and Dynamo DB
2. Use Github WOrflow to provision EKS CLuster using Terraform
3. Bootstrap EKS cluster with Bash Script to Install Ingress and Github Runner Self Hosted Controller.
4. Deploying Java Based Web Application using HELM Chart exposing through AWS LoadBalancer Controller Ingress.
5. Verify Application in the Browser.
6. Clean-Up (Sample Application and EKS Cluster and Node Groups)

## Step-01: Cloudformation Stack to Deploy Pre-requisites of Terraform and Github Actions.
Stack Location: cloudformation/oidc-infra-template.yml
```
aws cloudformation deploy \
	--stack-name OidcInfraTemplateStack \
	--template-file oidc-infra-template.yml \
	--capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" \
	--parameter-overrides \
	RepositoryName='muneebbukhari555/*' \
	BucketName='<s3BucketName>'\
	DynamoTableName='demo-table'
```
For Detail Steps, please see pdf Documents located at: /Documents

## Step-02: Provisioning Amazon EKS Cluster with Private endpoint
**Terraform Configs Folder:** terraform-eks/rak-eks-prod-cluster 

#### Terraform resources required to implement a working cluster including:
- VPC
- 6 subnets — 2 DB_Subnet, 2 Public, 2 Private for EKS Control Plane
- 1 NAT Gateway for Private Subnet
- VPC
- IAM Permissions
- ECR Registry
- EKS Cluster Private Endpoint Enabled, logging enabled
- Auto-scaling Group for Managed Private node group
- Create Access Entries for “Github_access_role” and “Admin_Access” Principal.

For Detail Steps, please see pdf Documents located at: /Documents
## Step-03: Bootstrap EKS cluster with Bash Script
We have used Bash Script to Install Self Hosted Github Runner and to Deploy app using flags.

```t
./cluster_bootstrap_script.sh -h -------> Show Help 
```
To Install utlities like  AWSCLI, Kubectl and HELM use the bash Script  with flag -i 
```t
./cluster_bootstrap_script.sh -i
```
After Installing utlities, we can now use connect with cluster and use HELM Chart for Deployments.
To use GITHUB ACTIONS workflow, we now Install SELF hosted Action Runner Controller, use the bash Script  with flag -g 
```t
./cluster_bootstrap_script.sh -g
```
To Deploy Application manually using HELM CHART, use the bash Script  with flag -a
```t
./cluster_bootstrap_script.sh -a
```
**When using shell script with flag -g and -a, it will ask following inputs to connect with cluster:**
1. AWS Region
2. Target Cluster Name
3. Role ARN to Assume
## Step-04: Deploying Java Application using Github CICD