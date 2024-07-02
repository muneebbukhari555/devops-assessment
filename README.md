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
 
Amazon Elastic Kubernetes Service (EKS) is a managed Kubernetes service that makes it easy for us to run Kubernetes on AWS without needing to install, operate, and maintain our own Kubernetes control plane or worker nodes. For Deploying endpoint private access for EKS cluster includes:

- create the VPC endpoints in the VPC and the traffic to the control plane will transverse via AWS network. Control plane will be accessible only from the VPC or connected networks like other VPCs or corporate networks connected to your VPC via TGW, direct gateway etc. The control plane will not be accessible from public internet. So to connect with EKS we will deploying Bastion Host within the VPC.
- specify minimum 2 private subnets in distinct AZs. EKS provisions two Elastic Network Interfaces (ENIs) in distinct AZs in our VPC to facilitate communication from control plane to worker node components. These ENIs are placed in the private subnets while creating the EKS cluster. These ENIs are owned and controlled by EKS. The kubelet use this ENIs to communicate to the API server.
- Amazon EKS worker nodes run in a VPC present in our AWS account . EKS managed worker nodes consists of a container runtime, kubelet and kube-proxy. The worker nodes can be placed in distinct AZs for high availability. Worker nodes and other services need connection to your cluster’s control plane use the API server  private endpoint and a certificate file that is created for cluster.

**EKS Cluster Access Management features:**

Cluster Access can be managed in two way:

1. Traditional it was by using ConfigMap `aws-auth`
    1. First, the AWS identity that creates an EKS cluster has automatic, invisible `system:masters` administrator privileges in the cluster that cannot be removed.
    2. Second, to grant access to an EKS cluster, you need to explicitly map AWS identities to Kubernetes groups using an in-cluster ConfigMap, `aws-auth`, that lives in the `kube-system` namespace. For instance, the following entry assigns the `developers` Kubernetes group to the `developer` AWS IAM role.
2. The new EKS Cluster Access Management capabilities
    1. We have used this method by granting access to an AWS principal on a our EKS cluster by:
        1. Creating an **access entry** for the principal. We will then assign permissions to that principal by mapping the access entry to Kubernetes groups, and/or **access policies**. 
        2. An access policy is an AWS-managed set of Kubernetes permissions.
    
    Can be listed using the command `aws eks list-access-policies`, such as:
    
    - `AmazonEKSClusterAdminPolicy`, equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) `cluster-admin` role
    - `AmazonEKSAdminPolicy`, equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) `admin` role
    - `AmazonEKSEditPolicy`, equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) `edit` role
    - `AmazonEKSViewPolicy`, equivalent to the [built-in](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) `view` role

Access Entry and Policies are deployed using terraform with the creation of EKS:
Terraform Directory includes three local modules:
1. VPC
2. Bastion Host
3. EKS

All three modules are called in parent module present at terraform root dir: main.tf
Sample tf var file that is used in our terraform apply: (One can edit as per required)
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
cluster_admin_user_arn          = "arn:aws:iam::<AccountID>>:user/<UserName>>"

```
**github_access_role_name** Terraform create this Role to Assume by Github to authenticate AWS using OIDC to access AWS Resources. This Role has appropriate policies attached with it to:
1. Push ECR Image into Private AWS Registry
2. To connect with EKS Cluster for App Deployment


**cluster_admin_user_arn** By providing this principal ARN, One can get access entry and will be able to use admin access on eks cluster.

We use Terraform to configure the cluster for creating ALB/NLB Ingress. This involves creating the necessary roles and permissions for the AWS Ingress Load Balancer Controller, which are then utilized by the AWS Deployment Controller's service account.
**system:serviceaccount:kube-system:aws-load-balancer-controller**


Files to create Roles and Permissions in /eks module under terrraform modules directory:
1. 08-github-oidc-role.tf (OIDC Based Assume role)
2. 09-access_entry_policy.tf (For Cluster Access)
3. 11-iam-oidc-connect-provider.tf (For OIDC Github provider in AWS)
4. 13-lbc-iam-policy-and-role.tf (For AWS Ingress ) 

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



For Detail Steps, please see pdf Documents located at: /Documents
**Terraform Configs Folder:** terraform-eks/rak-eks-prod-cluster
```t
By taking Refrence from Step 1 CLoud Formation Stack Output details, please initialize terraform as:

terraform init \
	-backend-config="region=<AWS_REGION>" \
	-backend-config="bucket=<s3BucketName>" \
	-backend-config="key=<TF_State_File_Key>" \
	-backend-config="dynamodb_table=<DYNAMODB_TABLE>"

terraform validate

terraform plan -var-file=./env-tfvars/rak-prod-demo.tfvars

terraform apply -var-file=./env-tfvars/rak-prod-demo.tfvars -auto-approve

To Destroy Provisioned Cluster:
terraform destroy -var-file=./env-tfvars/rak-prod-demo.tfvars -auto-approve
```
## Step-03: Bootstrap EKS cluster with Bash Script
Note: The principal executing the Bash script must have an IAM policy attached allowing them to assume a specified role.
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
A Bash script is used to install utilities, set up a self-hosted GitHub Runner, and deploy the app using specific flags.
Note: Run Bash Script with the root user privilege.

```t
./cluster_bootstrap_script.sh -h -------> Show Help 
```
**Installing utlities like  AWSCLI, Kubectl and HELM use the bash Script  with flag -i**
```t
./cluster_bootstrap_script.sh -i
```

**Installing Github Self Hosted Runner on EKS**
After installing the necessary utilities, we can connect to the cluster and use HELM charts for deployments. To utilize the GitHub Actions workflow, we install a self-hosted action runner.

We are now going to connect GitHub Personal Access Token (PAT) with our application to establish a connection between our repository and the AWS-deployed self-hosted runner. This process involves the following steps:

Generate a GitHub PAT:

1. Go to your GitHub account settings.
2. Navigate to Developer settings > Personal access tokens.
3. Click Generate new token.
4. Select the necessary scopes (permissions) for the token. 
5. Typically, we do repo and workflow scopes.
6. Generate the token and private key, along with the installation_id on the same browser page. Copy these securely and base64 encode them to store in the following file:

File location: github-action-runner/runner-secret.yaml

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
After inputs in above file, run the script:
```t
./cluster_bootstrap_script.sh -g
Script will ask for:
1. AWS Region
2. Target Cluster Name
3. Role ARN to Assume (arn:aws:iam::<Account_ID>>:role/GitHub_Actions_CICD_Role)
```


GitHub_Actions_CICD_Role is the same role, we created earlier using Trraform to give Github permission. Now we Assume this role using bash Script and deploy application in our EKS cluster manually.

**Installing Java Application on EKS**
To Deploy Application manually using HELM CHART, use the bash Script  with flag -a. Java App required to expose using Ingress:
- Aws-Load-Balancer-Controller (Ingress)

For Deploying Aws-Load-Balancer-Controller edit the file located at: aws-ingress-nginx/aws-alb-ingress.yaml
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

clusterName: "<ClusterName>" #rak-prod-eksdemo
region: "us-east-1"
vpcId: "<VPC_ID>>"
```
Once the inputs are ready, executing a bash script will pick up the YAML files and deploy the Java application, making it accessible via an exposed Ingress to the internet

APP Helm Chart values.yaml file:
```t
# Default values for java-web-app.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

replicaCount: 1

image:
  repository: 637423397994.dkr.ecr.us-east-1.amazonaws.com/java-web-app 
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: IMAGE_TAG 

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""

podSecurityContext: {}
  # fsGroup: 2000

securityContext: {}
  # capabilities:
  #   drop:
  #   - ALL
  # readOnlyRootFilesystem: true
  # runAsNonRoot: true
  # runAsUser: 1000

service:
  type: NodePort
  port: 8080

ingress:
  enabled: true
  className: "rak-ingress"
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
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:637423397994:certificate/04b7c3cb-336c-4fff-8927-121d119d6656
    #alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-1-2017-01 #Optional (Picks default if not used)    
    # SSL Redirect Setting
    alb.ingress.kubernetes.io/ssl-redirect: '443'   
  hosts:
    - host: app.digitaldense.com
      paths:
        - path: /
          pathType: Prefix
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

resources: 
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}

```
Edit the Ingress section and specify your desired hostname to expose. Annotations are included to redirect traffic from port 80 to 443. Use the annotation alb.ingress.kubernetes.io/certificate-arn to attach the ACM certificate ARN for HTTPS exposure on port 443.
```t
./cluster_bootstrap_script.sh -a
Script will ask for:
1. AWS Region
2. Target Cluster Name
3. Role ARN to Assume (arn:aws:iam::<Account_ID>>:role/GitHub_Actions_CICD_Role)
```

## Step-04: Complete CI/CD on EKS Cluster using GitHub Actions and Authenticate using RBAC and OIDC Provider

GitHub Action - It's a tool provided by GitHub to automate tasks in our software development workflow. We can use it to build, test, and deploy our code automatically whenever there are changes made to our GitHub repository. These automated tasks are defined using YAML files called workflows.

Creating a GitHub action workflow that accomplishes several key tasks: Testing and Building a Docker image, pushing it to the Amazon Elastic Container Registry (ECR), and ultimately deploying it to an Amazon Elastic Kubernetes Service (EKS) cluster

Details of the GitHub Actions YAML file provided: (.github/workflow/pipeline.yml)

- **Trigger**: This GitHub Action is triggered when someone pushes to the "main" branch.
- **Environment Variables**: Defines environment variables like the ECR repository name, EKS cluster name, and AWS region.
- **Jobs**: The “build” job is specified, which runs on the EKS Self Hosted Runner environment for better security control.
- **Steps**: The steps within the job are as follows:
  - **Set short git commit SHA:** This step retrieves the commit hash, which is used to tag the Docker image.
  **Check out code**: The action checks out the code from the "master" branch into the EKS Runner environmenrt.
  - **Configure AWS credentials**: Configure AWS credentials using secrets from GitHub. This step will fetch secrets from GitHub by assuming AWS Role.
  - **Login to Amazon ECR**: Log in to the Amazon Elastic Container Registry using OIDC Role to push the Docker image.
  - **Build, tag, and push the image to Amazon ECR**: This step builds the Docker image, tags it, and pushes it to ECR.
  - **Update kube config**: Fetches the Kubernetes configuration to interact with the EKS cluster.
  - **Deploy to EKS**: This part of the script applies Kubernetes manifests to deploy the application in EKS using HELM. It replaces a placeholder (`IMAGE_TAG`) in the manifest with the actual image tag.

