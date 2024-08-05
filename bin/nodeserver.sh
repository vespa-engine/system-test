#!/bin/sh
# Copyright Vespa.ai. All rights reserved.

SYSTEM_TEST=$HOME/git/system-test
export RUBYLIB=$SYSTEM_TEST/lib:$SYSTEM_TEST/tests
exec env VESPA_HOME=$HOME/vespa VESPA_USER=$(id -un) VESPA_SYSTEM_TEST_USE_TLS=true RUBYLIB=$RUBYLIB ruby $SYSTEM_TEST/lib/node_server.rb "$@"
