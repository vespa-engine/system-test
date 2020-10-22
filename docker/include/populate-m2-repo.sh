#!/bin/bash

set -e

readonly VESPA_VERSION=$(/opt/vespa/bin/vespa-print-default version)
readonly LOCAL_M2_REPO=/root/.m2/repository

source /opt/rh/rh-ruby*/enable
source /opt/rh/rh-maven*/enable

ruby /opt/vespa-systemtests/lib/maven_populator.rb --version $VESPA_VERSION --m2repo $LOCAL_M2_REPO
