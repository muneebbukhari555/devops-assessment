# Devops-Assessment

---
Deploying a Java Application to AWS EKS using GitHub Actions and IAC with Terraform
---

## Introduction
 In this repository, we will guide you through creating GitHub Action workflows that accomplish two primary tasks:

 
 1. Provisioning an Amazon EKS Cluster with a Private Endpoint using a GitHub workflow pipeline.

 2. Building a Docker image, pushing it to the Amazon Elastic Container Registry (ECR), and deploying it to an Amazon Elastic Kubernetes Service (EKS) cluster using a GitHub workflow pipeline.


We’ll break down each step in the following order:

1. Create Prerequisites with CloudFormation: Use a CloudFormation Stack to create prerequisites for Terraform EKS provisioning, such as Bitbucket, GitHub OIDC, IAM Role, and DynamoDB.

2. Provision EKS Cluster with GitHub Workflow: Use a GitHub Workflow pipeline to provision a Private Endpoint EKS Cluster using Terraform.

3. Bootstrap EKS Cluster: Preparing the EKS cluster with a Bash script to install Ingress and the GitHub Runner Self-hosted Controller for App CI/CD.

4. Deploy Java Web Application: Deploy a Java-based web application using a HELM Chart, exposing it through the AWS LoadBalancer Controller Ingress.

5. Verify Application: Verify the application in the browser.


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
For Detail Steps, please see pdf Documents located at: /doc

## Step-02: Provisioning Amazon EKS Cluster with Private endpoint
 
Amazon Elastic Kubernetes Service (EKS) is a managed Kubernetes service that simplifies running Kubernetes on AWS by eliminating the need to install, operate, and maintain our own Kubernetes control plane or worker nodes. Deploying a private endpoint access for an EKS cluster includes the following steps:

- Create the VPC endpoints in the VPC and the traffic to the control plane will transverse via AWS network. Control plane will be accessible only from the VPC or connected networks like other VPCs or corporate networks connected to your VPC via TGW, direct gateway etc. The control plane will not be accessible from public internet. So to connect with EKS we will deploying Bastion Host within the VPC.
- Specify minimum 2 private subnets in distinct AZs. EKS provisions two Elastic Network Interfaces (ENIs) in distinct AZs in our VPC to facilitate communication from control plane to worker node components. These ENIs are placed in the private subnets while creating the EKS cluster. These ENIs are owned and controlled by EKS. The kubelet use this ENIs to communicate to the API server.
- Amazon EKS worker nodes run in a VPC present in our AWS account . EKS managed worker nodes consists of a container runtime, kubelet and kube-proxy. The worker nodes can be placed in distinct AZs for high availability. Worker nodes and other services need connection to your cluster’s control plane use the API server  private endpoint and a certificate file that is created for cluster.

**EKS Cluster Access Management features:**

Cluster Access can be managed in two way:

1. Traditional way by using ConfigMap `aws-auth`
    1. First, the AWS identity that creates an EKS cluster has automatic, invisible `system:masters` administrator privileges in the cluster that cannot be removed.
    2. Second, to grant access to an EKS cluster, you need to explicitly map AWS identities to Kubernetes groups using an in-cluster ConfigMap, `aws-auth`, that lives in the `kube-system` namespace. For instance, the following entry assigns the `developers` Kubernetes group to the `developer` AWS IAM role.
2. The new EKS Cluster Access Management capabilities
    1. We are going to use this method by granting access to an AWS principal on a our EKS cluster by:
        1. Creating an **access entry** for the principal. We will then assign permissions to that principal by mapping the access entry to Kubernetes groups, and/or **access policies**. 
        2. An access policy is an AWS-managed set of Kubernetes permissions.
    
  Polciies can be listed using the command `aws eks list-access-policies`, such as:
    
    - AmazonEKSClusterAdminPolicy  equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) cluster-admin
    - AmazonEKSAdminPolicy         equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) admin        
    - AmazonEKSEditPolicy          equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) edit          
    - AmazonEKSViewPolicy          equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) view          

We are going to deploy access entry and policies using Terraform while provisioning an EKS cluster, we organize the Terraform directory to include three local modules: VPC, Bastion Host, and EKS. Here’s a detailed breakdown:

1. **VPC Module**:
   This module sets up the Virtual Private Cloud (VPC) along with private and public subnets, route tables, internet gateways, and Nat Gateway. It ensures network isolation and proper routing for your EKS cluster.
   
2. **Bastion Host Module**:
   This module provisions a Bastion Host, which serves as a secure access point for administrators to manage resources within the VPC. It configures security groups and SSH access. To access the provisioned EKS cluster, we need to allow inbound traffic on port 443 in the EKS cluster security group, specifying the Bastion Security Group as the source.

3. **EKS Module**:
   This module sets up the EKS cluster, including control plane and worker nodes. It configures IAM roles, node groups, security groups, and necessary Kubernetes configurations. It also includes provisions for private endpoint access, ensuring that the EKS control plane is accessible only within the VPC.

All three modules are invoked in the main module located at the root directory of the Terraform configuration: main.tf.

Sample tf var file that is used in our terraform apply: (Please edit as per required)
```t

# Generic Variables
aws_region       = "us-east-1"
environment      = "prod"
business_divsion = "rak"

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
instance_keypair = "eks-terraform-key" # key pair shuold be present in AWS

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
github_access_role_name         = "" 
cluster_admin_user_arn          = "" #The value for this variable is provided by the Terraform CLI using the -var flag.

```
**github_access_role_name** Terraform creates this role for GitHub to authenticate with AWS using OIDC, enabling access to AWS resources. This role is configured with appropriate policies to:
1. Push ECR Image into Private AWS Registry
2. To connect with EKS Cluster for App Deployment


**cluster_admin_user_arn** Terraform creates this role to grant access to the specified principal ARN, allowing administrative privileges on the EKS cluster through access entries.


Terraform also configures access for creating ALB/NLB Ingress within the cluster. This includes setting up roles and permissions for the AWS Ingress Load Balancer Controller, which are utilized by the AWS Deployment Controller's service account:

**system:serviceaccount:kube-system:aws-load-balancer-controller**


Files to create Roles and Permissions in /eks module under terrraform modules directory:
1. 08-github-oidc-role.tf (OIDC Based Assume role)
2. 09-access_entry_policy.tf (For Cluster Access)
2. 11-iam-oidc-connect-provider.tf (For OIDC Github provider in AWS)
3. 13-lbc-iam-policy-and-role.tf (For AWS Ingress ) 

###### Terraform resources required to implement a working cluster including:
- VPC
- 6 subnets — 2 DB_Subnet, 2 Public, 2 Private for EKS Control Plane
- 1 NAT Gateway for Private Subnet
- VPC
- IAM Permissions
- ECR Registry
- EKS Cluster Private Endpoint Enabled, logging enabled
- Auto-scaling Group for Managed Private node group
- Create Access Entries for “Github_access_role” and “Admin_Access” Principal.

**Terraform Configs Folder:** terraform-eks/rak-eks-prod-cluster
```t
By taking Refrence from Step 1 CLoud Formation Stack Output details, please initialize terraform as:

terraform init \
	-backend-config="region=<AWS_REGION>" \
	-backend-config="bucket=<s3BucketName>" \
	-backend-config="key=<TF_State_File_Key>" \
	-backend-config="dynamodb_table=<DYNAMODB_TABLE>"

terraform validate

terraform plan -var-file=./env-tfvars/rak-prod-demo.tfvars -var="aws_account_id=<Account_ID>" -var="cluster_admin_user_arn=<Principal _ARN>"

terraform apply -var-file=./env-tfvars/rak-prod-demo.tfvars -auto-approve -var="aws_account_id=<Account_ID>" -var="cluster_admin_user_arn=<Principal _ARN>"

To Destroy Provisioned Cluster:
terraform destroy -var-file=./env-tfvars/rak-prod-demo.tfvars -auto-approve -var="aws_account_id=<Account_ID>" -var="cluster_admin_user_arn=<Principal _ARN>"
```
## Step-03: Bootstrap EKS cluster with Bash Script
Note: To run script follow the pre-requisites:
1. Configure AWS user: **aws configure** The principal executing the Bash script must have an IAM policy attached allowing them to assume  role used in script.
```t
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::637423397994:role/GitHub_Actions_CICD_Role"
        }
    ]
}
```
2. Bash script is used to install utilities, set up a self-hosted GitHub Runner, Aws-Load-Balancer-Controller and deploy the app using specific flags.
Note: Run Bash Script with the root user privilege.
3. Make sure cluster accessibility. Allow inbound traffic on port 443 in the EKS cluster security group, specifying the Bastion Security Group as the source. 
4. Cluster_SG_Name: eks-cluster-sg-rak-prod-eksdemo-880488843
5. Bastion_SG_Name: rak-prod-public-bastion-sg-20240703200759981400000004

```t
./cluster_bootstrap_script.sh -h -------> Show Help 
```
**Installation of utlities like  AWSCLI, Kubectl and HELM use the bash Script  with flag -i**
```t
./cluster_bootstrap_script.sh -i
```

**Installation of Github Self Hosted Runner on EKS and Ingress Controller**
After installing the required utilities, we can connect to the cluster and deploy applications using HELM charts. To leverage the GitHub Actions workflow, we also install a self-hosted EKS action runner. For setting a mechanism to authenticate the action runner controller with GitHub.

Create a GitHub App for your organization, replace the ‘:org’ part of the following URL with your organization name before opening it. Then, enter any unique name in the “GitHub App name” field:

Select the below-mentioned permission for this app and hit the “Create GitHub App” button at the bottom of the page to create a GitHub App.

Repository Permissions

- Actions (read only)
- Administration (read and write)
- Checks (read only)
- Metadata (read only)
- Pull requests (read only)

Organization Permissions

- Self-hosted runners (read/write)
- Webhooks(read and write)

You will get:
1. An App ID on the page of the GitHub App you created.
2. The private key file, Download it by pushing the “Generate a private key” button.
3. Installation ID, after Installtion the last number of the URL will be used as the Installation ID  


Input above three values in File located at: github-action-runner/runner-secret.yaml

```t
apiVersion: v1
kind: Secret
metadata:
  name: controller-manager
  namespace: actions
type: Opaque
data:
  github_app_id: <base64 encoded>
  github_app_installation_id: <base64 encoded>
  github_app_private_key: |-
    (base64 encoded content of the private key file)

```
Replace placeHolder with the Required Account/Repo in file: github-action-runner/runner-deployments.yaml


```t
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: k8s-runner-deployment
  namespace: actions
spec:
  replicas: 1
  template:
    spec:
      repository: muneebbukhari555/devops-assessment
      labels:
        - "eks_runner"
```
Replace placeHolder with the Required Account/Repo in file: github-action-runner/horizontal-scale-runner.yaml
```t
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: self-hosted-runner-autoscaler
  namespace: actions
spec:
  scaleTargetRef:
    kind: RunnerDeployment
    name: k8s-runner-deployment
  scaleDownDelaySecondsAfterScaleOut: 300
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
    repositoryNames:
    - muneebbukhari555/devops-assessment
```
To expose a Java web application externally, an Ingress is required.

**Aws-Load-Balancer-Controller (Ingress):**
- Is a Kubernetes resource that defines the rules for routing external HTTP/S traffic to the appropriate services within your cluster.
- This is a controller that integrates with Kubernetes to provision AWS resources such as Application Load Balancers (ALB) or Network Load Balancers (NLB) based on the ingress resources defined in the cluster.
- It ensures that the ingress rules are translated into the appropriate configurations for the AWS load balancers.



For the Deployment of Aws-Load-Balancer-Controller edit the file located at: aws-lb-ingress/values.yaml
```t
image:
  repository: 602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller
  tag: v2.8.1
  pullPolicy: IfNotPresent

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::<Account_ID>>:role/rak-prod-eksdemo-lbc-iam-role" # Created this Role earlier by using Terraform resources ROles and Permissions

  # The name of the service account to use.
  name: aws-load-balancer-controller # (Created this Service Account earlier by using Terraform resources ROles and Permissions)

  # Automount API credentials for a Service Account.
  automountServiceAccountToken: true

clusterName: "<Cluster_Name>" #rak-prod-eksdemo
region: "<Region_Name>>"
vpcId: "<VPC_ID>>"
```
Once the inputs are ready run the script:
```t
./cluster_bootstrap_script.sh -g
Script will ask for:
1. AWS Region (e.ge us-east-1)
2. Target Cluster Name (e.g rak-prod-eksdemo)
3. Role ARN to Assume (arn:aws:iam::<Account_ID>>:role/GitHub_Actions_Role_NAME)
```


**GitHub_Actions_Role_NAME** is the same role, we created earlier using Trraform to provide Github permission. Now we Assume this role using bash Script and deploy application in our EKS cluster manually.

**Installation of Java Application and Sonarqube Server on EKS:**
To Deploy Application manually using HELM CHART, use the bash Script  with flag -a. 
For Deployment of SonarQube edit the file located at: sonarqube/values.yaml
```t
ingress:
  enabled: true
  # Used to create an Ingress record.
  className: "ingress-external"
  annotations: 
    alb.ingress.kubernetes.io/load-balancer-name: eks-ingress-external
    alb.ingress.kubernetes.io/scheme: internet-facing
    # Health Check Settings
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-path: /app
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    ## SSL Settings
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}, {"HTTP":80}]'
    alb.ingress.kubernetes.io/certificate-arn: <ACM Cert ARN>
    # SSL Redirect Setting
    alb.ingress.kubernetes.io/ssl-redirect: '443'
  hosts:
    - name: <hostname>
      # Different clouds or configurations might need /* as the default path
      path: /*

service:
  type: NodePort

postgresql:
  persistence:
    enabled: false
```
Edit the Ingress section and specify desired hostname to expose. Annotations are included to redirect traffic from port 80 to 443. Use the annotation alb.ingress.kubernetes.io/certificate-arn to attach the ACM certificate ARN for HTTPS exposure on port 443.

Java APP Helm Chart values.yaml file: Helm_Chart/java-web-app/values.yaml
```t
# Default values for java-web-app.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

replicaCount: 1

image:
  repository: <Account_ID>.dkr.ecr.us-east-1.amazonaws.com/java-web-app 
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: IMAGE_TAG 

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""



service:
  type: NodePort
  port: 8080

ingress:
  enabled: true
  className: "ingress-external"
  annotations:
    alb.ingress.kubernetes.io/load-balancer-name: ingress-java-web-app
    alb.ingress.kubernetes.io/scheme: internet-facing
    # Health Check Settings
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-path: /app
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    ## SSL Settings
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}, {"HTTP":80}]'
    alb.ingress.kubernetes.io/certificate-arn: <ACM Cert ARN>
    #alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-1-2017-01 #Optional (Picks default if not used)    
    # SSL Redirect Setting
    alb.ingress.kubernetes.io/ssl-redirect: '443'   
  hosts:
    - host: <hostname>
      paths:
        - path: /
          pathType: Prefix
  tls: []



```
Edit the Ingress section and specify desired hostname to expose. Annotations are included to redirect traffic from port 80 to 443. Use the annotation alb.ingress.kubernetes.io/certificate-arn to attach the ACM certificate ARN for HTTPS exposure on port 443.

Once the inputs are ready, executing a bash script will pick up the YAML files and deploy the Java application, making it accessible via an exposed Ingress to the internet
```t
./cluster_bootstrap_script.sh -a
Script will ask for:
1. AWS Region
2. Target Cluster Name
3. Role ARN to Assume (arn:aws:iam::<Account_ID>>:role/GitHub_Actions_CICD_Role)
4. Application Name   (In our case java-web-app)
```
Create DNS Record for both services against HOSTNAME used in Ingress Section:
- Sonarqube
- Java-Web-App

In Record target value provide alias for AWS Ingress LoadBalancer.

**NOTE:** Initially Web APP will not get online as we don't have any registry image present in ECR. In step 4 we are going to use workflow to build and deploy Web APP Image.
## Step-04: Application CI/CD on EKS Cluster using GitHub Actions and Authenticate using RBAC and OIDC Provider

GitHub Action - It's a tool provided by GitHub to automate tasks in our software development workflow. We can use it to build, test, and deploy our code automatically whenever there are changes made to our GitHub repository. These automated tasks are defined using YAML files called workflows.

In this project, we are going to setup workflow with more secure way. For this I have created an Identity provider in AWS and assigned it a role with minimum policy needed for ECR and EKS. 
- Every time our job runs, GitHub’s OIDC Provider auto-generates an OIDC token. Once the AWS successfully validates the claims presented in the token, it then provides a short-lived cloud access token that is available only for the duration of the job.
- We dont need to store AWS credentials as a long-lived secret on Github which has access to all the resource in AWS.
- We have granular control over providing access to cloud resources. With OIDC, AWS issues a short-lived access token that is only valid for a single job, and then automatically expires.


GitHub CI/CD action workflow accomplishes several key tasks: 
1. Testing and Building a Docker image, pushing it to the Amazon Elastic Container Registry (ECR)
2. Deploying application to an Amazon Elastic Kubernetes Service (EKS) cluster

For code quality we have integrated **SonarQube** with GitHub Actions CICD. SonarQube is a self-managed, automatic code review tool that systematically helps you deliver clean code. As a core element of our Sonar solution , SonarQube integrates into your existing workflow and detects issues in your code to help you perform continuous code inspections of your projects.

https://github.com/marketplace/actions/official-sonarqube-scan



GitHub Actions YAML file provided: (.github/workflow/cicd-pipeline.yml)

**Prerequisites**
The pipeline is designed generically and utilizes repository secrets to facilitate CI/CD for application. 
Required Repo secrets are:
- AWS_ACCOUNT_ID
- AWS_REGION
- ECR_REPO
- EKS_CLUSTER_NAME
- APP_NAME
- PAT
- ROLE_NAME
- SONAR_HOST_URL
- SONAR_TOKEN

To integrate SonarQube with GitHub Actions, we are going to:
- Create Token in SonarQube to authenticate with GitHub Actions
- Add Sonar Token, SonarQube URL as Secrets in GitHub Actions
- Run Workflow in Self Hosted Runner
- Verify scan report in SonarQube

GitHub Action CICD Pipeline Workflow build and push Docker Image tags through Semantic Release. A separate workflow for maintaing semantic release is craeted other than main CI/CD pipeline.

**Trigger**: The release-please workflow will run on every push to the main branch and handle version bumping and tagging based on your commit messages. Commit contains the following structural elements:
  1. fix: which represents bug fixes, and correlates to a SemVer patch.
  2. feat: which represents a new feature, and correlates to a SemVer minor.
  3. feat!:, or fix!:, refactor!:, etc., which represent a breaking change (indicated by the !) and will result in a SemVer major.


For Reference: https://www.conventionalcommits.org/en/v1.0.0/
- **Environment Variables**: Defines environment variables like the ECR repository name, EKS cluster name, and AWS region.
- **Jobs**: The “build” job is specified, which runs on the EKS Self Hosted Runner environment for better security control.
- **Steps**: The steps within the job are as follows:
  - **Check out code**: The action checks out the code from the "master" branch into the EKS Runner environmenrt.
  - **Maven Build:** Add tasks for Maven build.
  - **SonarQube** SonarQube Analysis
  - **Buildx Stage** Building Docker Context
  - **Configure AWS credentials**: Configure AWS credentials using secrets from GitHub. This step will fetch secrets from GitHub by assuming AWS Role.
  - **Login to Amazon ECR**: Log in to the Amazon Elastic Container Registry using OIDC Role to push the Docker image.
  - **Docker Image MetaData** Dynamically creating Image tag from MetaData using Semantic Versioning
  - **Build, tag, and push the image to Amazon ECR**: This step builds the Docker image, tags it, and pushes it to ECR.
  - **Update kube config**: Fetches the Kubernetes configuration to interact with the EKS cluster.
  - **Deploy to EKS**: This part of the script applies Kubernetes manifests to deploy the application in EKS using HELM. It replaces a placeholder (`IMAGE_TAG`) in the manifest with the actual image tag.