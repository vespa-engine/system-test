<!-- Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root. -->

# Vespa system tests framework

The Vespa system test framework is an automatic testing tool for creating and running
system tests. It is loosely based upon the methodology used in JUnit and
similar unit test frameworks, but it has added functionality for testing at system level
using multiple nodes. It is written in pure Ruby.

## Table of Contents

- [Background](#background)
- [Usage](#usage)
- [Contribute](#contribute)
- [License](#license)

## Background

Repo layout: Library files that contain the framework itself are in lib/,
the tests are in tests/ and utilities and automatic runners are in bin/.

Multinode testing is well supported since the framework is largely based upon RPC calls using
DRb (distributed ruby). Methods for feeding data, checking an online index or doing a query
and so on are executed in the context of one of the nodes in the Vespa installation.
Each of the nodes must be running a ruby process called <i>node_server.rb</i> that acts as a server
for the RPC calls.

## Usage

Follow these steps to install and run system tests

### 1. Create CentOS 7 dev environment

Follow the 'Create dev environment' section in: [Create C++ / Java dev environment on CentOS using VirtualBox and Vagrant](https://github.com/vespa-engine/vespa/blob/master/vagrant/README.md)

### 2. Add Vespa systemtest runtime dependencies:

<pre>sudo yum -y install \
  libxml2-devel \
  rh-ruby23-rubygems-devel \
  rh-ruby23-ruby-devel \
  rh-ruby23</pre>

### 3. Add more Vespa systemtest runtime dependencies:

<pre>
sudo bash
. /opt/rh/rh-ruby23/enable
gem install libxml-ruby gnuplot distribution 
exit</pre>

### 4. Compile vespa:

<pre>cd $HOME/git/vespa
sh bootstrap.sh java
mvn --batch-mode --threads 2C -nsu install -DskipTests -Dmaven.javadoc.skip=true
sh bootstrap-cpp.sh -u . .
make -j 5
make install</pre>

### 5. Run systemtests in newly created Vespa systemtest enviroment

#### 5.1 Modify .bash_profile to include the following in PATH:
* $HOME/git/systemtests/bin/centos

#### 5.2 Ensure hostname is set to localhost
<pre>sudo hostname localhost</pre>

#### 5.3 In terminal window 1

<pre>nodeserver.sh</pre>

#### 5.4 In terminal window 2

<pre>cd $HOME/git/systemtests
cd tests/search/basicsearch
runtest.sh basic_search.rb --run test_basicsearch__ELASTIC</pre>

## Contribute

We welcome contributions - see [Contributing.md](Contributing.md)

## License

Code licensed under the Apache 2.0 license. See [LICENSE](LICENSE) for terms.

