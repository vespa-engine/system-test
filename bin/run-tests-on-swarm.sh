#!/usr/bin/env bash
# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

set -euo pipefail

usage() {
  echo "Usage: run-tests-on-swarm.sh [OPTIONS]"
  echo
  echo "Run all or a subset of system tests on Docker swarm"
  echo
  echo "Required options:"
  echo "-i, --image          Docker image to use. When using multiple swarm nodes, the image must"
  echo "                     be available from a central repository."
  echo "-n, --nodes          Number of service nodes"
  echo
  echo "Optional options:"
  echo "-c, --consoleoutput  Output test execution on console/stdout."
  echo "-f, --file           Testfile to execute. Relative to tests/ directory. Can be repeated."
  echo "                     If not specified, all test files in tests/ will be discovered."
  echo "-k, --keeprunning    Keep the test containers running. Only use this option when executing"
  echo "                     specific tests. Otherwise all test nodes will be used and tests will hang waiting."
  echo "-m, --mount          Bind mount to include in both node and testrunner containers."
  echo "                     This will not work correctly if multiple swarm nodes are used. "
  echo "                     Format is <local file/folder>:<container destination>"
  echo "-p, --performance    Run performance tests."
  echo "-r, --resultdir      Directory to store results. Will auto allocate in \$HOME/tmp/systemtest.XXXXXX"
  echo "-v, --verbose        Print debug output"
  exit 1
}

if [[ $# == 0 ]]; then usage;fi
if [[ $(echo $BASH_VERSION|cut -d. -f1) < 4 ]]; then
  echo "ERROR: Requires bash 4 or better."; echo; usage
fi

if ! docker service ls &> /dev/null; then
  echo "ERROR: Requires Docker swarm to be running."; echo; usage
fi

# Option parsing
POSITIONAL=()
CONSOLEOUTPUT=false
DOCKERIMAGE=""
KEEPRUNNING=false
MOUNTS=()
NUMNODES=""
PERFORMANCE=false
RESULTDIR=""
TESTFILES=()
VERBOSE=false
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --help)
    usage
    shift
    ;;
    -c|--consoleoutput)
    CONSOLEOUTPUT=true
    shift
    ;;
    -f|--file)
    TESTFILES+=("$2")
    shift; shift
    ;;
    -i|--image)
    DOCKERIMAGE="$2"
    shift; shift
    ;;
    -m|--mount)
    MOUNTS+=("$2")
    shift; shift
    ;;
    -k|--keeprunning)
    KEEPRUNNING=true
    shift
    ;;
    -n|--nodes)
    NUMNODES="$2"
    shift; shift
    ;;
    -p|--performance)
    PERFORMANCE=true
    shift
    ;;
    -r|--resultdir)
    RESULTDIR="$2"
    shift; shift
    ;;
    -v|--verbose)
    VERBOSE=true
    shift
    ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done

if [[ ${#POSITIONAL[@]} > 0 ]]; then
  set -- "${POSITIONAL[@]}"
fi

if [[ -z $DOCKERIMAGE   ]]; then usage; fi
if [[ -z $NUMNODES   ]]; then usage; fi
if [[ -z $RESULTDIR ]]; then 
  mkdir -p $HOME/tmp
  RESULTDIR=$(mktemp -d $HOME/tmp/systemtest.XXXXXX)
fi
TESTRUNNER_OPTS="-n $NUMNODES"
if [[ ${#TESTFILES[@]} > 0 ]]; then
  for F in "${TESTFILES[@]}"; do
    TESTRUNNER_OPTS="$TESTRUNNER_OPTS -f $F"
  done
fi
if $CONSOLEOUTPUT; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -c"
fi
if $KEEPRUNNING; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -k"
fi
if $PERFORMANCE; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -p"
fi
if $VERBOSE; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -v"
fi
BINDMOUNT_OPTS=""
if [[ ${#MOUNTS[@]} > 0 ]]; then
  for M in "${MOUNTS[@]}"; do
    BINDMOUNT_OPTS="$BINDMOUNT_OPTS --mount type=bind,src=${M%:*},dst=${M#*:}"
  done
fi

readonly BASEDIR=/tmp/testresults
readonly NETWORK="$USER-vespa"
readonly TESTRUNNER="$USER-testrunner"
readonly SERVICE="$USER-vespanode"
readonly VESPAVERSION=$(docker run --rm $BINDMOUNT_OPTS --entrypoint env $DOCKERIMAGE /opt/vespa/bin/vespa-print-default version)

TESTRUNNER_OPTS="$TESTRUNNER_OPTS -b $BASEDIR -V $VESPAVERSION"

log() {
  echo "[$(date -u +'%Y-%m-%d %H:%M:%S %z')] $*"
}
log_debug() {
  if [[ $VERBOSE != 0 ]]; then
    log "DEBUG" $1
  fi
}
log_info() {
  log "INFO" $1
}
log_error() {
  log "ERROR" $1
}

log_debug ""
log_debug "Options:"
log_debug "--  DOCKERIMAGE:     $DOCKERIMAGE"
log_debug "--  NETWORK:         $NETWORK"
log_debug "--  SERVICE:         $SERVICE"
log_debug "--  NUMNODES:        $NUMNODES"
log_debug "--  KEEPRUNNING:     $KEEPRUNNING"
log_debug "--  PERFORMANCE:     $PERFORMANCE"
log_debug "--  RESULTDIR:       $RESULTDIR"
log_debug "--  TESTRUNNER_OPTS: $TESTRUNNER_OPTS"
log_debug "--  BINDMOUNT_OPTS:  $BINDMOUNT_OPTS"
log_debug "--  VESPAVERSION:    $VESPAVERSION"
if [[ ${#POSITIONAL[@]} > 0 ]]; then
  log_debug "--  NOT PARSED:      ${POSITIONAL[*]}"
fi
log_debug ""

# Remove service and network
docker_cleanup() {
  if docker service ps $SERVICE &> /dev/null; then
    if ! docker service rm $SERVICE &> /dev/null; then
      log_debug "Could not remove service $SERVICE"
    else
      while [[ -n $(docker ps | grep "$SERVICE\.[0-9].*") ]]; do
        log_debug "Waiting for service $SERVICE to shut down."
        sleep 2
      done
      log_debug "Removed service $SERVICE."
    fi
  fi

  if docker network inspect $NETWORK &> /dev/null; then
    if ! docker network rm $NETWORK &> /dev/null; then
      log_debug "Could not remove network $NETWORK"
    else
      while [[ -n $(docker network ls | grep "$NETWORK.*swarm") ]]; do
        log_debug "Waiting for network $NETWORK to be removed."
        sleep 2
      done
      log_debug "Removed network $NETWORK."
    fi
  fi
}

docker_cleanup

if ! docker network create --driver overlay --attachable $NETWORK &> /dev/null; then
  log_error "Could not create network $NETWORK. Exiting."; docker_cleanup; exit 1
else
  if ! docker service create --replicas $NUMNODES --hostname "{{.Service.Name}}.{{.Task.Slot}}.{{.Task.ID}}.$NETWORK" \
                             --name $SERVICE --env NODE_SERVER_OPTS="-c $TESTRUNNER.$NETWORK:27183" \
                             $BINDMOUNT_OPTS --network $NETWORK --detach $DOCKERIMAGE &> /dev/null; then
    log_error "Could not create service $SERVICE. Exiting."; docker_cleanup; exit 1
  fi
fi

docker run --privileged --rm \
           $BINDMOUNT_OPTS \
           -v $RESULTDIR:$BASEDIR \
           --name $TESTRUNNER \
           --hostname $TESTRUNNER.$NETWORK \
           --network $NETWORK \
           --entrypoint bash $DOCKERIMAGE -lc \
           "source /opt/rh/rh-ruby27/enable && ruby /opt/vespa-systemtests/lib/testrunner.rb $TESTRUNNER_OPTS" 

if ! $KEEPRUNNING; then
  docker_cleanup
fi

echo
log_info "Test results available in $RESULTDIR"
echo
