<!-- Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root. -->

# Vespa system tests framework

[![Build Status](https://cd.screwdriver.cd/pipelines/7039/test-system-tests/badge)](https://cd.screwdriver.cd/pipelines/7039)


The Vespa system test framework is an automatic testing tool for creating and running
system tests. It is loosely based upon the methodology used in JUnit and
similar unit test frameworks, but it has added functionality for testing at system level
using multiple nodes. It is written in pure Ruby.

## Table of Contents

- [Background](#background)
- [Install](#install)
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

## Install

Before running system tests, build and install Vespa following the steps in the development guide:
[Vespa development on CentOS Stream 8](https://github.com/vespa-engine/docker-image-dev#vespa-development-on-centos-stream-8).

## Usage
### Vespa development

Follow the [run system tests](https://github.com/vespa-engine/docker-image-dev#run-system-tests)
section of the development guide.

### System test development
Developed system tests can be tested locally using Docker Swarm.

Initialize Docker Swarm if not done previously:

```
$ docker swarm init
```

Build Docker image with updated files and execute:

```
$ docker build --file docker/Dockerfile --tag ${USER}-systemtests .
$ bin/run-tests-on-swarm.sh --consoleoutput --image ${USER}-systemtests --nodes 1 --file search/basicsearch/basic_search.rb
```

For information about the capabilities of ```run-tests-on-swarm.sh```:

```
$ bin/run-tests-on-swarm.sh --help
```


## Contribute

We welcome contributions - see [contributing](https://github.com/vespa-engine/vespa/blob/master/CONTRIBUTING.md)

## License

Code licensed under the Apache 2.0 license. See [LICENSE](LICENSE) for terms.

