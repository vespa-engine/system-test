#!/bin/sh

# Use this script to run one of the following performance tests locally:
#   vespa - ecommerce_hybrid_search.rb
#   elasticsearch - ecommerce_hybrid_search_es.rb
#   elasticsearch-force-merged - ecommerce_hybrid_search_es_merge_1.rb
#
# The performance results of a run are placed in a JSON file in perf_results/$VERSION.
# Use the create_report.py script to generate a report based on the results of the above three runs.
#
print_usage() {
    echo "Usage $0 {vespa|elasticsearch|elasticsearch-force-merged}"
}

VERSION=8.427.7
CONTAINER_NAME=system-tests
DOCKER_IMAGE=docker.io/vespaengine/vespa-systemtest-preview
TEST_DIR=/system-test/tests/performance/ecommerce_hybrid_search
export RUBYLIB="/system-test/lib:/system-test/tests"
delete_tmp_dir=true

run_perf_test() {
    local test_path=$TEST_DIR/$2
    echo "Running performance test for $1 ($test_path)"
    podman pull $DOCKER_IMAGE:$VERSION
    podman run --privileged --rm --name $CONTAINER_NAME -ti -v $PWD/../../../:/system-test -w /system-test -e RUBYLIB=$RUBYLIB --entrypoint /usr/bin/env $DOCKER_IMAGE:$VERSION bash -l -c "ruby /system-test/lib/node_server.rb & sleep 3; ruby $test_path --outputdir $TEST_DIR/tmp"
}

copy_perf_results() {
    local results_path=perf_results/$VERSION/$1.json
    echo "Copying performance results to $results_path"
    mkdir -p perf_results/$VERSION
    cp tmp/$2/hybrid_search/results/all_perf.json $results_path
}

if [ "$#" -ne 1 ]; then
    print_usage
    exit 1
fi

case "$1" in
  vespa)
    run_perf_test "$1" "ecommerce_hybrid_search.rb"
    copy_perf_results "$1" "EcommerceHybridSearchTest"
    ;;
  elasticsearch)
    run_perf_test "$1" "ecommerce_hybrid_search_es.rb"
    copy_perf_results "$1" "EcommerceHybridSearchESTest"
    ;;
  elasticsearch-force-merged)
    run_perf_test "$1" "ecommerce_hybrid_search_es_merge_1.rb"
    copy_perf_results "$1" "EcommerceHybridSearchESForceMerge1Test"
    ;;
  *)
    echo "Invalid option: $1"
    print_usage
    exit 1
    ;;
esac

if [ "$delete_tmp_dir" = true ]; then
    echo "Deleting tmp directory storing output from performance test run"
    rm -rf tmp
fi

