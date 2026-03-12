#!/bin/sh

set -e
set -x

dnf install -y dnf-plugins-core
/usr/bin/crb enable
dnf -y --nobest upgrade

dnf install -y \
    bind-utils \
    git-core \
    hostname \
    jq \
    libxml2-devel \
    lz4 \
    make \
    net-tools \
    redhat-rpm-config \
    sudo \
    wget \
    zstd


dnf -y install java-$JAVA_VERSION-openjdk-devel
dnf -y install vespa-maven

# needed to compile gems (and possibly pip modules?)
dnf install -y gcc

dnf -y install \
    python3-devel \
    python3-pip

pip3 install --no-cache-dir --upgrade pip
pip3 install --no-cache-dir xgboost scikit-learn cbor2

dnf module enable -y ruby:$RUBY_VERSION
dnf -y install \
    ruby \
    ruby-devel \
    rubygems-devel \
    rubygem-bigdecimal \
    rubygem-builder \
    rubygem-concurrent-ruby \
    rubygem-rexml \
    rubygem-test-unit

gem install ffi libxml-ruby parallel
dnf remove -y gcc

dnf -y install \
    gcc-toolset-$GCC_VERSION-gcc-c++ \
    gcc-toolset-$GCC_VERSION-libatomic-devel \
    gcc-toolset-$GCC_VERSION-annobin-plugin-gcc

curl -sSLf "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2-$(uname -m).zip"
unzip -q awscliv2-$(uname -m).zip
./aws/install
rm -rf aws awscliv2-$(uname -m).zip

if [ -d /context-root/rpms ]; then
    printf "%s\n" \
	  "[vespa-rpms-local]" \
	  "name=Local Vespa RPMs" \
	  "baseurl=file:///context-root/rpms/" \
	  "enabled=1" \
	  "gpgcheck=0" > /etc/yum.repos.d/vespa-rpms-local.repo
else
     echo "Missing /context-root/rpms"
fi

dnf -y install vespa-systemtest-tools

if [ "$(/opt/vespa/bin/vespa-print-default sanitizers)" != none ]; then
    dnf debuginfo-install -y \
        vespa-abseil-cpp vespa-libzstd vespa-lz4 vespa-onnxruntime \
        vespa-openblas vespa-openssl vespa-protobuf glibc libatomic \
        libffi libgcc libgfortran libicu libstdc++ llvm-libs \
        ncurses-libs re2 xxhash-libs zlib
    dnf debuginfo-install -y \
        vespa vespa-base-libs vespa-libs vespa-malloc
fi

# Clear all dynamic debuginfo URLs. Current specific issue related to this is
# that libelfutils wants to download info when interrupting 'perf record'.
# Depending on network setup for Docker/Podman this might hang forever.
rm -rf /etc/debuginfod/*

mkdir -p /opt/vespa/.m2
cp /context-root/include/local-maven-repo-settings.xml /opt/vespa/.m2/settings.xml
cp /context-root/include/populate-m2-repo.sh /opt/vespa/.m2

dnf clean all
rm -f /etc/yum.repos.d/vespa-rpms-local.repo
rm -rf /var/cache/dnf
