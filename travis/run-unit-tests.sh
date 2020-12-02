#!/usr/bin/env bash

# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

set -e

cat /proc/cpuinfo
cat /proc/meminfo
df -h
ulimit -a

export RUBYLIB=/source/lib

yum -y install \
  libxml2-devel \
  rh-ruby25-rubygems-devel \
  rh-ruby25-ruby-devel \
  rh-ruby25 \
  rh-ruby25-rubygem-net-telnet

source /opt/rh/devtoolset-9/enable
source /opt/rh/rh-ruby25/enable

gem install libxml-ruby gnuplot distribution test-unit builder

cd ${RUBYLIB}
ruby test/testrunner.rb
exit $?
