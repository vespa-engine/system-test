#!/bin/bash

set -e

K8S_NAMESPACE="$1"
CLUSTER="vespa-system-test"
SERVICE_ACCOUNT="vespa-tester"
ROLE_ARN="arn:aws:iam::381492154096:role/vespa-system-test-role"

kubectl create namespace $K8S_NAMESPACE || true
kubectl config set-context --current --namespace=$K8S_NAMESPACE

# Cleanup if we have old stuff lying around
kubectl delete all --all || true
kubectl delete -f kubernetes/testrunner || true
kubectl delete secret svc-identity --ignore-not-found

# Create pod identity association
aws eks create-pod-identity-association \
  --cluster-name $CLUSTER \
  --namespace $K8S_NAMESPACE \
  --service-account $SERVICE_ACCOUNT \
  --role-arn $ROLE_ARN || true
