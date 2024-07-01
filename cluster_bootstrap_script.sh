#!/bin/bash

usage() {
  echo "Usage: ./cluster_bootstrap_script.sh [options]"
  echo "Options:"
  echo '  -i                Use to Install Kubectl, AWS CLI, Helm to interact with k8s API' >&2
  echo '  -s                Use to deploy Ingress Controller, certificate Manager for expose and use TLS communication' >&2
  echo '  -g                Use to deploy ARC Action Runner Controller' >&2
  echo '  -c                Target Cluster Name e.g rak-prod-eksdemo' >&2
  echo '  -l                Target Cluster Region Name' >&2
  echo '  -a                Application Name e.g -a java-web-app. Use to deploy Java Web App in the cluster' >&2
  echo '  -r                Assume Role ARN to get login into AWS and execute the script' >&2
  exit 1
}

log () {
    local MESSAGE="${@}"
    echo "${MESSAGE}"
    logger -t ${0} "${MESSAGE}"
}

# Make sure the script is being executed with superuser privileges.
if [[ ${UID} -ne 0 ]]
then
  echo 'You are not authroized to perform this Action!!' >&2
  exit 1
fi

# Read parameters required
while getopts isga:c:r: OPTION
do
  case ${OPTION} in
    i)
      utilities=true
      ;;
    s)
      Ingress_CertManger=true
      ;;
    a)  
      app_name=${OPTARG}
      deploy_app=true
      ;;
    g)
      github_runner=true
      ;;
    c)
      EKS_CLUSTER_NAME=${OPTARG}
      ;;
    l)
      AWS_REGION=${OPTARG}
      ;;
    r)
      AWS_ROLE_ARN=${OPTARG}
      ;;
    \?)  
      usage
      ;;
  esac
done

####### Configuring Authentication for AWS using Temporary Creds #########
echo "Region: $AWS_REGION"
echo "EKS Cluster: $EKS_CLUSTER_NAME"

# Assume the IAM role and export the temporary credentials
ROLE_ARN=AWS_ROLE_ARN #"arn:aws:iam::637423397994:role/GitHub_Actions_CICD_Role"
SESSION_NAME="AssumeGitHubActionsRoleSession"

TEMP_CREDENTIALS=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $SESSION_NAME)

export AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDENTIALS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $TEMP_CREDENTIALS | jq -r '.Credentials.SessionToken')

# Check if credentials are set correctly
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo "Failed to assume role and retrieve credentials."
    exit 1
fi

# Verify the temporary credentials
aws sts get-caller-identity

if [ $? -ne 0 ]; then
    echo "Cluster Authentication failed"
    exit 1
fi


##### Installing Utlities in the cluster. ######
if [[ ${utilities} = 'true' ]]
then
  log "Installing AWS CLI Version: v2"
  sudo apt install unzip -y
  sudo apt install jq -y
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  aws --version 

  log "Installing kubectl CLI Version: v1.30" 
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  kubectl version --client

  log "Installing Helm Version: v3" 
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  helm version

  if [[ "${?}" -ne 0 ]]
  then
    echo "Utilities are not Installted Correctly." >&2
    exit 1
  fi
fi

######Installing Certificate Manager and Ingress for Exposing App######
if [[ ${Ingress_CertManger} = 'true' ]]
then
  # Log into the Cluster
  aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER_NAME}
  if [[ "${?}" -ne 0 ]]
  then
    echo "Cluster Authentication failed" >&2
    exit 1
  fi
  log "######Installing Ingress for Exposing App######"
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace cert-manager \
  --create-namespace \
  --version=4.9.0 

  log "Installing CertManager for TLS Communication"
  helm repo add jetstack https://charts.jetstack.io --force-update
  helm repo update

  helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace\
  --version v1.14.0\
  --set installCRDs=true
fi

###### Installing Action Runnder Controller ######
if [[ ${github_runner} = 'true' ]]
then
  # Log into the Cluster
  aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER_NAME}
  if [[ "${?}" -ne 0 ]]
  then
    echo "Cluster Authentication failed" >&2
    exit 1
  fi
  #Creation Secrets in k8s cluster
  kubectl apply -f github-action-runner/runner-secret.yaml

  # Adding Helm Repo 
  helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
  helm repo update
  # ARC HELM CMD
  helm install \
  actions-runner-controller actions-runner-controller/actions-runner-controller \
  --namespace actions \
  --create-namespace \
  --version 0.22.0 \
  --set syncPeriod=1m
  
  # Runner Deployment 
  kubectl apply -f github-action-runner/runner-deployments.yaml
  kubectl apply -f github-action-runner/horizontal-scale-runner.yaml
fi

###### Deploy Web App ######
if [[ ${deploy_app} = 'true' ]]
then
  # Log into the Cluster
  aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER_NAME}
  if [[ "${?}" -ne 0 ]]
  then
    echo "Cluster Authentication failed" >&2
    exit 1
  fi
  echo 'Utilities are Installing'
  namespace=${app_name}
  kubectl create ns ${namespace}
  helm upgrade --install ${app_name} ./helm_chart/${app_name} -n ${namespace}
fi
