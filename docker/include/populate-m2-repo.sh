#!/bin/bash

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <user>"
  exit 1
fi

readonly THE_USER=$1
readonly THE_HOME_DIR=$(getent passwd $THE_USER |cut -d: -f 6)

readonly VESPA_VERSION=$(rpm -q vespa --queryformat '%{VERSION}')
readonly LOCAL_M2_REPO=$THE_HOME_DIR/.m2/repository

if [[ -n $(find /opt/rh -mindepth 1 -maxdepth 1 -type d -name "rh-ruby*") ]]; then
  source /opt/rh/rh-ruby*/enable
fi

if [[ -n $(find /opt/rh -mindepth 1 -maxdepth 1 -type d -name "rh-maven*") ]]; then
  source /opt/rh/rh-maven*/enable
fi

readonly SHARED_MVN_OPTS="--threads 1C -Dvespa.version=${VESPA_VERSION} -Dmaven.repo.local=${LOCAL_M2_REPO} --batch-mode --file /opt/vespa-systemtests/tests/pom.xml"

# Install parent pom
mvn $SHARED_MVN_OPTS --non-recursive install
# Resolve all dependencies recursively
mvn $SHARED_MVN_OPTS dependency:go-offline
