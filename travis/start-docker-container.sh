#!/usr/bin/env bash

# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

set -e

docker run --rm -v $(pwd):/source --entrypoint /source/travis/run-unit-tests.sh docker.io/vespaengine/vespa-build-centos7:latest
exit $?
