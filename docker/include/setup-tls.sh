#!/bin/bash

source /opt/rh/rh-ruby*/enable

# Auto generate cert and key
env USER=root /opt/vespa-systemtests/lib/node_server.rb &
PID=$!
sleep 3
kill -9 $PID

# Setup the Vespa TLS config
mkdir -p /opt/vespa/conf/vespa/tls
cat << EOF > /opt/vespa/conf/vespa/tls/tls_config.json
{
    "disable-hostname-validation": true,
    "files": {
        "ca-certificates": "/opt/vespa/conf/vespa/tls/ca.pem",
        "certificates": "/opt/vespa/conf/vespa/tls/host.pem",
        "private-key": "/opt/vespa/conf/vespa/tls/host.key"
    }
}
EOF
cp -a /root/.vespa/system_test_certs/ca.pem /opt/vespa/conf/vespa/tls
cp -a /root/.vespa/system_test_certs/host.pem /opt/vespa/conf/vespa/tls
cp -a /root/.vespa/system_test_certs/host.key /opt/vespa/conf/vespa/tls
chown -R vespa:vespa /opt/vespa/conf/vespa/tls
     
