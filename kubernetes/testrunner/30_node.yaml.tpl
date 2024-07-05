apiVersion: v1
kind: ConfigMap
metadata:
  name: vespa-test-node-scripts
data:
  run.sh: |
    #!/bin/bash
    ORIGINAL_HOSTNAME=$(hostname)
    IP_ADDRESS=$(hostname -i)
    WAIT_UNTIL=$(( $(date +%s) + 30 ))
    while ! host $IP_ADDRESS; do
      sleep 2
      echo "Waiting for DNS resolve of $IP_ADDRESS"
      if [[ $(date +%s) -gt $WAIT_UNTIL ]]; then
        exit 1
      fi
    done
    HOSTNAME=$(host $(hostname -i) | awk '{print $NF}' | sed 's,\.$,,')
    hostname $HOSTNAME
    echo $HOSTNAME > /etc/hostname
    sed "s,$ORIGINAL_HOSTNAME,$HOSTNAME,g" /etc/hosts > /tmp/hosts
    cp /tmp/hosts /etc/hosts
    export VESPA_HOSTNAME=$HOSTNAME

    CONTROLLER_HOST_PORT="vespa-test-controller.__K8S_NAMESPACE__.svc.cluster.local:27183"
    while [[ $? != 56 ]]; do
      sleep 2
      curl -f $CONTROLLER_HOST_PORT
    done

    # Wait until all configservers resolve in DNS
    WAIT_UNTIL=$(( $(date +%s) + 120 ))
    i=0
    while (( $i < __SHARED_CONFIGSERVERS__ )); do
      CONFIGSERVER=vespa-test-cfg-${i}.vespa-test-cfg.__K8S_NAMESPACE__.svc.cluster.local
      while ! host $CONFIGSERVER; do
        echo "Waiting for DNS resolve of $CONFIGSERVER"
        sleep 2
        if [[ $(date +%s) -gt $WAIT_UNTIL ]]; then
          exit 1
        fi
      done
      i=$(( $i + 1 ))
    done

    # Prefer local memory when we split hosts running several tests
    sed -i 's,numactl --interleave all,numactl --localalloc,' /opt/vespa/libexec/vespa/common-env.sh

    # Start the node server
    source /opt/rh/gcc-toolset-*/enable
    export VESPA_TESTDATA_URL="s3://__AWS_ACCOUNT__-vespa-factory-testdata"
    set -e
    /usr/bin/ruby /opt/vespa-systemtests/lib/node_server.rb -c $CONTROLLER_HOST_PORT

  stop.sh: |
    #!/bin/bash
    /usr/bin/ruby -e 'require "environment"; require "drb_endpoint"; DrbEndpoint.new("#{Socket.gethostname}:27183").create_client(with_object: nil).shutdown'

---
apiVersion: batch/v1
kind: Job
metadata:
  name: vespa-test-node
  labels:
    app: vespa-test-node
spec:
  completions: 2000
  completionMode: Indexed
  parallelism: __TESTS_IN_PARALLEL__
  ttlSecondsAfterFinished: 0
  backoffLimit: 2000
  template:
    metadata:
      annotations:
        karpenter.sh/do-not-evict: "true"
      labels:
        app: vespa-test-node
    spec:
      nodeSelector:
        nodegroup: __TEST_NODE_GROUP__
      priorityClassName: system-node-critical
      serviceAccountName: vespa-tester
      restartPolicy: OnFailure
      shareProcessNamespace: true
      containers:
        - name: vespa-test-node
          image: __CONTAINER_IMAGE__:__VESPA_VERSION__
          imagePullPolicy: IfNotPresent
          securityContext:
            capabilities:
              add: [ "SYSLOG", "SYS_PTRACE", "SYS_ADMIN", "SYS_NICE" ]
          command:
            - /mnt/scripts/run.sh
          env:
            - name: PARENT_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          ports:
            - containerPort: 27183
          #readinessProbe:
          #  tcpSocket:
          #    port: 27183
          #  initialDelaySeconds: 5
          #  periodSeconds: 10
          volumeMounts:
            - name: host-var-lib-sia
              mountPath: /var/lib/sia
            - name: node-scripts
              mountPath: /mnt/scripts
          resources:
            limits:
              cpu: "__TEST_NODE_CPU__"
              memory: "__TEST_NODE_MEMORY__"
          lifecycle:
            preStop:
              exec:
                command:
                  - /mnt/scripts/stop.sh
      tolerations:
        - key: DeletionCandidateOfClusterAutoscaler
          operator: Exists
          effect: PreferNoSchedule
        - key: dedicated
          operator: Equal
          value: "__TEST_NODE_GROUP__"
          effect: NoSchedule
      topologySpreadConstraints:
        - maxSkew: 100
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
      volumes:
        - name: host-var-lib-sia
          hostPath:
            path: /var/lib/sia
        - name: node-scripts
          configMap:
            name: vespa-test-node-scripts
            defaultMode: 0555
