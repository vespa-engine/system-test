#!/bin/bash

set -ex

AWS_REGION=${AWS_REGION:-"eu-west-1"}
K8S_CLUSTER=${K8S_CLUSTER:-"vespa-system-test"}
PROFILE="external-factory"

# Update AWS credentials
awscreds -d vespa.external.factory -r admin -p $PROFILE -z public

# Get bastion instance ID
BASTION_ID=$(aws --profile $PROFILE ec2 describe-instances \
  --region $AWS_REGION \
  --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=vespa-system-test-bastion" \
  --query 'Reservations[*].Instances[*].[InstanceId]' \
  --output text)
echo "Found bastion instance: $BASTION_ID"

# Get API server endpoint
AWS_EKS_CLUSTER_ENDPOINT=$(aws --profile $PROFILE eks describe-cluster \
  --name $K8S_CLUSTER \
  --query "cluster.endpoint" \
  --output text | sed 's/https:\/\///')

# Start port forwarding in background
aws --profile $PROFILE ssm start-session \
  --region $AWS_REGION \
  --target $BASTION_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"portNumber\":[\"443\"],\"localPortNumber\":[\"4443\"],\"host\":[\"$AWS_EKS_CLUSTER_ENDPOINT\"]}" &
