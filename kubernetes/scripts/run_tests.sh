#!/bin/bash

set -e

kubectl create -f kubernetes/testrunner/

WAIT_UNTIL=$(( $(date +%s) + $(( 10 * 60 )) ))
while [[ $(kubectl get pods/vespa-test-controller -o jsonpath='{.status.phase}') != Running ]]; do
  kubectl get all || true
  if [[ $(date +%s) -le $WAIT_UNTIL ]]; then
    echo "Waiting for controller activation until : $(date --date=@$WAIT_UNTIL)"
    sleep 5
  else
    echo "Test controller failed to enter Runnning state."
    kubectl describe --show-events pods/vespa-test-controller || true
    return 1
  fi
done

while true; do
  echo "Waiting for controller success"

  # set +x
  CONTROLLER_JSON=$(kubectl get pods/vespa-test-controller -o json)
  CONTROLLER_NODE_NAME=${CONTROLLER_NODE_NAME:-$(jq -re '.spec.nodeName' <<< "$CONTROLLER_JSON" || true)}
  CONTROLLER_POD_PHASE=$(jq -re '.status.phase' <<< "$CONTROLLER_JSON" || true)
  TESTJOB_JSON=$(kubectl get jobs/vespa-test-node -o json)

  if [[ -z "$TESTJOB_JSON" ]]; then
    # The job does not exist and there is no point running further
    return 1
  else
    echo "vespa-test-node job status:"
    jq -re '.status' <<< "$TESTJOB_JSON"
  fi
  # set -x

  case $CONTROLLER_POD_PHASE in
    Succeeded)
    # meta set vespa.factory.status success #TODO: fixme
      echo "Test controller succeeded"
      break
      ;;
    Failed)
      kubectl describe pods/vespa-test-controller
      return 1
      ;;
    "")
      kubectl logs pods/vespa-test-controller || true
      kubectl describe node/$CONTROLLER_NODE_NAME --show-events || true
      kubectl get events || true
      kubectl get events -n default || true
      FAIL_COUNT=$(( ${FAIL_COUNT:-0} + 1 ))
      if (( $FAIL_COUNT > 2 )); then
        echo "Empty pod phase detected $FAIL_COUNT times. Aborting."
        return 1
      fi
      ;;
    *)
      echo "Current pods/vespa-test-controller phase is $CONTROLLER_POD_PHASE"
      (kubectl get pods -l app=vespa-test-node --field-selector=status.phase==Failed -o=custom-columns=NAME:.metadata.name --no-headers \
      | xargs -I{} -n 1 kubectl logs pods/{} ) || true
      kubectl get nodes -l nodegroup="${TEST_NODE_GROUP}" || true
      ;;
  esac
  # There is a cleanup delay in Kubernetes where completed jobs and pods are removed within 20s. Make sure we do not miss a state.
  sleep 18
done

echo "Test controller succeeded, waiting for test job to finish"
FACTORY_JOB_RUN_TEST_STATUS=success
