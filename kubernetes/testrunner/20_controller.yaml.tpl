---
apiVersion: v1
kind: Service
metadata:
  name: vespa-test-controller
spec:
  clusterIP: None
  selector:
    app: vespa-test-controller
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vespa-test-controller-scripts
data:
  run.sh: |
    #!/bin/bash

    mkdir $HOME/.athenz
    ln -sf /var/lib/sia/certs/vespa.vespa.factory.fleks-test-dev-us-east-1.cert.pem $HOME/.athenz/cert
    ln -sf /var/lib/sia/keys/vespa.vespa.factory.fleks-test-dev-us-east-1.key.pem   $HOME/.athenz/key
    source /opt/rh/gcc-toolset-*/enable

    # Wait until all configservers answer on 19071
    i=0
    CONFIGSERVER_OPTS=""
    while (( $i < __SHARED_CONFIGSERVERS__ )); do
      CONFIGSERVER=vespa-test-cfg-${i}.vespa-test-cfg.__K8S_NAMESPACE__.svc.cluster.local
      while [[ $? != 60 ]]; do
        sleep 2
        curl -sf "https://$CONFIGSERVER:19071"
      done
      CONFIGSERVER_OPTS="$CONFIGSERVER_OPTS -c $CONFIGSERVER"
      i=$(( $i + 1 ))
    done

    # We must wait until the service is up an $VESPA_HOSTNAME resolves. The DRB client depends on it.
    while ! host $VESPA_HOSTNAME; do
      sleep 2
      echo "Waiting for $VESPA_HOSTNAME to resolve in DNS."
    done

    export VESPA_TESTDATA_URL="s3://__AWS_ACCOUNT__-vespa-factory-testdata"
    RESULTS_DIR="/tmp/testresults"
    
    if [[ __TEST_TYPE__ =~ ^perf.* ]]; then
      PERF_TEST_OPTS="-p"
    fi

    mkdir -p $RESULTS_DIR/logs
    cd $RESULTS_DIR

    while true; do aws s3 sync ./logs/ __VESPA_TESTRESULTS_URL__/logs/ ; sleep 30; done &
    SYNC_PID=$!
    # We want error code to propatate if testrunner.rb exits
    set -e -o pipefail
    /usr/bin/ruby /opt/vespa-systemtests/lib/testrunner.rb -v -w 900 -V __VESPA_VERSION__ -i __SD_BUILD_ID__ -b $RESULTS_DIR \
        -d 15 -n __TESTS_IN_PARALLEL__ $CONFIGSERVER_OPTS $PERF_TEST_OPTS __TEST_RUNNER_EXTRA_OPTS__ \
        | tee $RESULTS_DIR/logs/test-controller-$(date +'%Y-%m-%d_%H%M').log

    kill $SYNC_PID
    aws s3 sync ./ __VESPA_TESTRESULTS_URL__/

  factory_authentication.rb: |
    require 'openssl'
    require 'net/https'
    require 'json'

    class FactoryAuthentication
      def initialize
        @factory_api = URI.parse('https://factory.vespa.aws-us-east-1a.vespa.oath.cloud')
        @token_uri = URI.parse('https://zts.athenz.ouroath.com:4443/zts/v1/oauth2/token')
        @token = nil
        @token_expires_at = 0
        @token_lock = Mutex.new
        @key_cert_location = discover_key_and_cert
      end

      def factory_api
        @factory_api
      end

      def client
        http_client(@factory_api)
      end

      def token
        get_access_token
      end

    private

      ALL_NET_HTTP_ERRORS = [
        Timeout::Error,  EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, Net::HTTPError,
        Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Errno::EPIPE, Errno::EINVAL, Errno::ECONNRESET,
        Errno::EHOSTUNREACH
      ]

      def get_access_token()
        @token_lock.synchronize do
          if Time.now.to_i > @token_expires_at
            location = discover_key_and_cert

            if location
              begin
                http = http_client(@token_uri)
                request = Net::HTTP::Post.new(@token_uri.request_uri)
                request.body = 'grant_type=client_credentials&scope=vespa.vespa:domain'.encode
                request.add_field('User-Agent', @user_agent)

                token_json = JSON.parse(http.request(request).body)
                @token = token_json["access_token"]
                @token_expires_at = Time.now.to_i + token_json["expires_in"].to_i - 60 # 60 second slack
              rescue *ALL_NET_HTTP_ERRORS => e
                raise "Could not get access token. Exception: #{e.message}"
              end
            else
              raise 'No key and cert files found.'
            end
          end
          @token
        end
      end

      def discover_key_and_cert
        locations = []
        locations << { :cert => '/var/lib/sia/certs/vespa.vespa.factory.systemtest.cert.pem',
                       :key => '/var/lib/sia/keys/vespa.vespa.factory.systemtest.key.pem' }
        locations << { :cert => '/var/lib/sia/certs/vespa.vespa.factory.builder.cert.pem',
                       :key => '/var/lib/sia/keys/vespa.vespa.factory.builder.key.pem' }
        locations << { :cert => '/sd/tokens/cert',
                       :key => '/sd/tokens/key' }
        locations << { :cert => "#{Dir.home}/.athenz/cert",
                       :key => "#{Dir.home}/.athenz/key" }

        locations.each do |location|
          return location if (File.exist?(location[:cert]) && File.exist?(location[:key]))
        end
      end

      def ssl_cert(cert)
        OpenSSL::X509::Certificate.new(File.read(cert))
      end

      def ssl_key(key)
        OpenSSL::PKey::RSA.new(File.read(key))
      end

      def http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.cert = ssl_cert(@key_cert_location[:cert])
        http.key = ssl_key(@key_cert_location[:key])
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.read_timeout = 120
        http.write_timeout = 120
        http.ssl_version = :TLSv1_2 # TODO allow TLSv1.3 once https://bugs.ruby-lang.org/issues/19017 is resolved
        http
      end
    end
---
apiVersion: v1
kind: Pod
metadata:
  name: vespa-test-controller
  annotations:
    karpenter.sh/do-not-evict: "true"
  labels:
    app: vespa-test-controller
spec:
  nodeSelector:
    nodegroup: __CONTROLLER_NODE_GROUP__
  priorityClassName: system-node-critical
  serviceAccountName: vespa-tester
  restartPolicy: Never
  shareProcessNamespace: true
  containers:
    - command:
        - /mnt/scripts/run.sh
      env:
        - name: RUBYLIB
          value: "/mnt/scripts:/opt/vespa-systemtests/controller:/opt/vespa-systemtests/lib/factory:/opt/vespa-systemtests/lib-internal:/opt/vespa-systemtests/lib:/opt/vespa-systemtests/tests-internal:/opt/vespa-systemtests/tests"
        - name: VESPA_HOSTNAME
          value: "vespa-test-controller.__K8S_NAMESPACE__.svc.cluster.local"
        - name: VESPA_FACTORY_NO_AUTORUNNER
          value: "1"
      image: __CONTAINER_IMAGE__:__VESPA_VERSION__
      imagePullPolicy: IfNotPresent
      name: vespa-test-controller
      securityContext:
        runAsUser: 0
        runAsGroup: 0
        capabilities:
          add: [ "SYSLOG", "SYS_PTRACE", "SYS_ADMIN", "SYS_NICE" ]
      ports:
        - containerPort: 27183
      resources:
        limits:
          cpu: "__CONTROLLER_NODE_CPU__"
          memory: "__CONTROLLER_NODE_MEMORY__"
      volumeMounts:
        - name: host-var-lib-sia
          mountPath: /var/lib/sia
        - name: controller-scripts
          mountPath: /mnt/scripts

  tolerations:
    - key: dedicated
      operator: Equal
      value: "__CONTROLLER_NODE_GROUP__"
      effect: NoSchedule

  volumes:
    - name: host-var-lib-sia
      hostPath:
        path: /var/lib/sia
    - name: controller-scripts
      configMap:
        name: vespa-test-controller-scripts
        defaultMode: 0555

