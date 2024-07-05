---
apiVersion: v1
kind: Service
metadata:
  name: vespa-test-cfg
spec:
  clusterIP: None
  selector:
    app: vespa-test-cfg
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vespa-test-cfg-scripts
data:
  run.sh: |
    #!/bin/bash
    export VESPA_CONFIGSERVERS=$(i=0; while (( $i < __SHARED_CONFIGSERVERS__ )); do echo "vespa-test-cfg-${i}.vespa-test-cfg.__K8S_NAMESPACE__.svc.cluster.local"; i=$(( $i + 1 )); done | xargs | sed 's/\ /,/g')
    export VESPA_CONFIGSERVER_JVMARGS="__SHARED_CONFIGSERVERS_JVMARGS__"
    export VESPA_CONFIGSERVER_MULTITENANT=true
    export VESPA_SYSTEM=dev
    /opt/vespa/bin/vespa-start-configserver

    while true; do
      sleep 60
      aws s3 sync /opt/vespa/logs/ __VESPA_TESTRESULTS_URL__/logs/configservers/$(hostname)/
      /opt/vespa/bin/vespa-logfmt -N | tail -100
    done

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vespa-test-cfg
  labels:
    app: vespa-test-cfg
spec:
  replicas: __SHARED_CONFIGSERVERS__
  podManagementPolicy: Parallel
  serviceName: vespa-test-cfg
  selector:
    matchLabels:
      app: vespa-test-cfg
  template:
    metadata:
      annotations:
        karpenter.sh/do-not-evict: "true"
      labels:
        app: vespa-test-cfg
    spec:
      nodeSelector:
        nodegroup: __SHARED_CONFIGSERVERS_NODE_GROUP__
      priorityClassName: system-node-critical
      serviceAccountName: vespa-tester
      restartPolicy: Always
      shareProcessNamespace: true
      containers:
        - command:
            - /mnt/scripts/run.sh
          image: __CONTAINER_IMAGE__:__VESPA_VERSION__
          imagePullPolicy: IfNotPresent
          name: vespa-test-cfg
          securityContext:
            capabilities:
              add: [ "SYSLOG", "SYS_PTRACE", "SYS_ADMIN", "SYS_NICE" ]
          ports:
            - containerPort: 19071
          readinessProbe:
            tcpSocket:
              port: 2181 # Use the zk port here to allow all replicas to start
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            limits:
              cpu: "__SHARED_CONFIGSERVERS_CPU__"
              memory: "__SHARED_CONFIGSERVERS_MEMORY__"
          volumeMounts:
            - name: cfg-scripts
              mountPath: /mnt/scripts

      tolerations:
        - key: dedicated
          operator: Equal
          value: "__SHARED_CONFIGSERVERS_NODE_GROUP__"
          effect: NoSchedule

      volumes:
        - name: cfg-scripts
          configMap:
            name: vespa-test-cfg-scripts
            defaultMode: 0555

