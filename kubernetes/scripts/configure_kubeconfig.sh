#!/bin/bash

set -ex

AWS_REGION=${AWS_REGION:-"eu-west-1"}
K8S_CLUSTER=${K8S_CLUSTER:-"vespa-system-test"}
K8S_NAMESPACE=${K8S_NAMESPACE:-"vespa-system-test"}
PROFILE="external-factory"

# Update AWS credentials
awscreds -d vespa.external.factory -r admin -p $PROFILE -z public

# Load kubeconfig
aws --profile $PROFILE eks update-kubeconfig --name $K8S_CLUSTER --region $AWS_REGION

# Point kubectl to local port forward
K8S_CLUSTER=arn:aws:eks:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):cluster/$K8S_CLUSTER
echo "127.0.0.1 kubernetes.default" | sudo tee -a /etc/hosts
kubectl config set-cluster $K8S_CLUSTER --server=https://kubernetes.default:4443
kubectl config use-context $K8S_CLUSTER

# Wait to verify connection
for i in {1..10}; do
  if kubectl get ns &>/dev/null; then
    echo "Successfully connected to Kubernetes cluster"
    break
  fi
  if [ $i -eq 10 ]; then
    echo "Failed to connect to Kubernetes cluster"
    exit 1
  fi
  sleep 3
done
