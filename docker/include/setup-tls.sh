#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <user>"
  exit 1
fi

readonly THE_USER=$1
readonly THE_HOME_DIR=$(getent passwd $THE_USER |cut -d: -f 6)

if [[ -n $(find /opt/rh -mindepth 1 -maxdepth 1 -type d -name "rh-ruby*") ]]; then
  source /opt/rh/rh-ruby*/enable
fi

# Auto generate cert and key
export PATH=/opt/vespa-deps/bin:$PATH
env USER=$THE_USER /opt/vespa-systemtests/lib/node_server.rb --generate-tls-env-and-exit

# Setup the Vespa TLS config
mkdir -p /opt/vespa/conf/vespa/tls
cat << EOF > $THE_HOME_DIR/.vespa/system_test_certs/tls_config.json
{
    "disable-hostname-validation": true,
    "files": {
        "ca-certificates": "/opt/vespa/conf/vespa/tls/ca.pem",
        "certificates": "/opt/vespa/conf/vespa/tls/host.pem",
        "private-key": "/opt/vespa/conf/vespa/tls/host.key"
    }
}
EOF
cp -a $THE_HOME_DIR/.vespa/system_test_certs/ca.pem /opt/vespa/conf/vespa/tls
cp -a $THE_HOME_DIR/.vespa/system_test_certs/host.pem /opt/vespa/conf/vespa/tls
cp -a $THE_HOME_DIR/.vespa/system_test_certs/host.key /opt/vespa/conf/vespa/tls
cp -a $THE_HOME_DIR/.vespa/system_test_certs/tls_config.json /opt/vespa/conf/vespa/tls

VESPA_USER=$(grep " VESPA_USER " /opt/vespa/conf/vespa/default-env.txt | awk '{print $NF}')
if [[ -n $VESPA_USER ]]; then
  chown -R $VESPA_USER:$(id -gn $VESPA_USER) /opt/vespa/conf/vespa/tls
fi

