#!/usr/bin/env bash

# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

set -e

export RUBYLIB=/source/lib

yum -y install \
  libxml2-devel \
  rh-ruby23-rubygems-devel \
  rh-ruby23-ruby-devel \
  rh-ruby23 \
  rh-ruby23-rubygem-net-telnet

source /opt/rh/devtoolset-8/enable
source /opt/rh/rh-ruby23/enable

gem install libxml-ruby gnuplot distribution test-unit builder

cd ${RUBYLIB}
ruby test/testrunner.rb
exit $?
