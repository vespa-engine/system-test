#!/bin/sh
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

SYSTEM_TEST=$HOME/git/system-test
export RUBYLIB=$SYSTEM_TEST/lib:$SYSTEM_TEST/tests
exec env VESPA_HOME=$HOME/vespa VESPA_USER=$(id -un) VESPA_SYSTEM_TEST_USE_TLS=true RUBYLIB=$RUBYLIB ruby $SYSTEM_TEST/lib/node_server.rb "$@"
