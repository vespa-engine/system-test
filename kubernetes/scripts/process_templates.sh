#!/bin/bash

# Default values for parameters
CONTAINER_IMAGE=${CONTAINER_IMAGE:-"vespaengine/vespa-systemtest-preview"}
NODE_ARCH=${NODE_ARCH:-"arm64"}
SHARED_CONFIGSERVERS=${SHARED_CONFIGSERVERS:-"1"}
FACTORY_PLATFORM=${FACTORY_PLATFORM:-"public_centos7"}
TEST_TYPE=${TEST_TYPE:-"system"}
TESTS_IN_PARALLEL=${TESTS_IN_PARALLEL:-"40"}
TEST_NODE_CPU=${TEST_NODE_CPU:-"3.5"}
TEST_NODE_MEMORY=${TEST_NODE_MEMORY:-"15G"}
TEST_NODE_GROUP=${TEST_NODE_GROUP:-"spot"}

# TODO: Get unique build id from the build system
SD_BUILD_ID="$1"
if [ -z "$SD_BUILD_ID" ]; then
    echo "Error: SD_BUILD_ID environment variable is not set."
    exit 1
fi

VESPA_VERSION="$2"
if [ -z "$VESPA_VERSION" ]; then
    echo "Error: VESPA_VERSION environment variable is not set."
    exit 1
fi

K8S_NAMESPACE="vespa-$TEST_TYPE-$NODE_ARCH"
if [ -z "$K8S_NAMESPACE" ]; then
    echo "Error: K8S_NAMESPACE environment variable is not set."
    exit 1
fi
export $K8S_NAMESPACE
echo "K8S_NAMESPACE: $K8S_NAMESPACE"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install it before running this script."
    exit 1
fi

# Check if kubernetes/testrunner directory exists
if [ ! -d "kubernetes/testrunner" ]; then
    echo "Error: kubernetes/testrunner directory does not exist."
    exit 1
fi

# # Get AWS account from config
# AWS_ACCOUNT=$(yq '.aws.account-id' $FLEKS_CONFIG_PATH)
# if [ -z "$AWS_ACCOUNT" ]; then
#     echo "Error: Could not extract AWS account from $FLEKS_CONFIG_PATH"
#     exit 1
# fi
#
# TODO: Find the way to get AWS_ACCOUNT from infrastructure-templates repo
AWS_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
echo "AWS_ACCOUNT: $AWS_ACCOUNT"

# TODO: Find where to store SD_ARTIFACTS_DIR
SD_ARTIFACTS_DIR="artifacts"

# Generate VESPA_TESTRESULTS_URL
#
# TODO: Split bucket per build.
VESPA_TESTRESULTS_URL="s3://${AWS_ACCOUNT}-vespa-system-test/${VESPA_VERSION}/$(date +'%Y-%m-%d_%H%M')"

echo "Processing template files..."

for tpl in $(ls kubernetes/testrunner/*.tpl); do
  echo "Processing $tpl"
  sed -e "s,__AWS_ACCOUNT__,$AWS_ACCOUNT,g" \
      -e "s,__CONTAINER_IMAGE__,$CONTAINER_IMAGE,g" \
      -e "s,__CONTROLLER_NODE_CPU__,${CONTROLLER_NODE_CPU:-3.5},g" \
      -e "s,__CONTROLLER_NODE_MEMORY__,${CONTROLLER_NODE_MEMORY:-23G},g" \
      -e "s,__CONTROLLER_NODE_GROUP__,${CONTROLLER_NODE_GROUP:-on-demand},g" \
      -e "s,__K8S_NAMESPACE__,$K8S_NAMESPACE,g" \
      -e "s,__NODE_ARCH__,$NODE_ARCH,g" \
      -e "s,__SD_BUILD_ID__,$SD_BUILD_ID,g" \
      -e "s,__SHARED_CONFIGSERVERS__,$SHARED_CONFIGSERVERS,g" \
      -e "s,__SHARED_CONFIGSERVERS_CPU__,${SHARED_CONFIGSERVERS_CPU:-3.5},g" \
      -e "s,__SHARED_CONFIGSERVERS_MEMORY__,${SHARED_CONFIGSERVERS_MEMORY:-15G},g" \
      -e "s,__SHARED_CONFIGSERVERS_JVMARGS__,${SHARED_CONFIGSERVERS_JVMARGS:-"-verbose:gc -Xms12g -Xmx12g"},g" \
      -e "s,__SHARED_CONFIGSERVERS_NODE_GROUP__,${SHARED_CONFIGSERVERS_NODE_GROUP:-on-demand},g" \
      -e "s,__TEST_NODE_CPU__,${TEST_NODE_CPU:-3.5},g" \
      -e "s,__TEST_NODE_MEMORY__,${TEST_NODE_MEMORY:-15G},g" \
      -e "s,__TEST_NODE_GROUP__,${TEST_NODE_GROUP},g" \
      -e "s,__TEST_RUNNER_EXTRA_OPTS__,$TEST_RUNNER_EXTRA_OPTS,g" \
      -e "s,__TEST_TYPE__,$TEST_TYPE,g" \
      -e "s,__TESTS_IN_PARALLEL__,$TESTS_IN_PARALLEL,g" \
      -e "s,__VESPA_TESTRESULTS_URL__,$VESPA_TESTRESULTS_URL,g" \
      -e "s,__VESPA_VERSION__,$VESPA_VERSION,g" \
      "$tpl" > "${tpl%.*}"
done

echo "Creating artifacts directory..."
mkdir -p "$SD_ARTIFACTS_DIR/rendered-yaml"

echo "Copying yaml files to artifacts directory..."
cp kubernetes/testrunner/*.yaml "$SD_ARTIFACTS_DIR/rendered-yaml"

echo "Script completed successfully."
