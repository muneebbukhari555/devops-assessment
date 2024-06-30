#!/bin/bash

usage() {
  echo "Usage: ./cluster_bootstrap_script.sh [options]"
  echo "Options:"
  echo '  -i                Use to Install Kubectl, AWS CLI, Helm to interact with k8s API' >&2
  echo '  -s                Use to deploy Ingress Controller, certificate Manager for expose and use TLS communication' >&2
  echo '  -a                Use to deploy Java Web App in the cluster' >&2
  echo '  -g                Use to deploy ARC Action Runner Controller' >&2
  exit 1
}

log () {
    local MESSAGE="${@}"
    if [[ ${VERBOSE} = true ]]
    then
        echo "${MESSAGE}"
    fi
    logger -t ${0} "${MESSAGE}"
}

# Make sure the script is being executed with superuser privileges.
if [[ ${UID} -ne 0 ]]
then
  echo 'You are not authroized to perform this Action!!' >&2
  exit 1
fi

# Read parameters required
while getopts isa:g OPTION
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
    ?)  usage
      ;;
  esac
done

# Installing Utlities in the cluster.
if [[ ${utilities} = 'true' ]]
then
  # Installing AWS CLI Version: v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install

  # Installing kubectl CLI Version: v1.30
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  kubectl version --client

  # Installing Helm Version: v3
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
fi

if [[ ${Ingress_CertManger} = 'true' ]]
then
  # Installing CertManager for TLS Communication
  helm repo add jetstack https://charts.jetstack.io --force-update

  helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace\
  --version v1.14.0\
  --set installCRDs=true
fi

if [[ ${utilities} = 'true' ]]
then
  # Installing Action Runnder Controller
  #Creation Secrets in k8s cluster
  Kubectl apply -f github-action-runner/runner-secret.yaml

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
  Kubectl apply -f github-action-runner/runner-deployments.yaml
  Kubectl apply -f github-action-runner/horizontal-scale-runner.yaml
  
fi

if [[ ${deploy_app} = 'true' ]]
then
  echo 'Utilities are Installing'
  kubectl create ns java-web-app
  helm upgrade --install ${app_name} helm_chart/${app_name}
fi
