FROM vespaengine/vespa

ARG SKIP_M2_POPULATE

RUN yum -y install --setopt=skip_missing_names_on_install=False \
                   rh-maven35 libxml2-devel rh-ruby27 rh-ruby27-rubygems-devel rh-ruby27-ruby-devel \
                   rh-ruby27-rubygem-net-telnet devtoolset-11-gcc-c++ git && \
    source /opt/rh/rh-ruby27/enable && \
    source /opt/rh/devtoolset-11/enable && \
    gem install libxml-ruby gnuplot distribution test-unit builder concurrent-ruby ffi && \
    alternatives --set java java-11-openjdk.x86_64 && \
    alternatives --set javac java-11-openjdk.x86_64 && \
    yum --enablerepo='*' clean all 

ENV RUBYLIB=/opt/vespa-systemtests/lib:/opt/vespa-systemtests/tests

COPY . /opt/vespa-systemtests

RUN /opt/vespa-systemtests/docker/include/setup-tls.sh root

ENV VESPA_TLS_CONFIG_FILE=/opt/vespa/conf/vespa/tls/tls_config.json

RUN if [[ "$SKIP_M2_POPULATE" != "true" ]]; then /opt/vespa-systemtests/docker/include/populate-m2-repo.sh root; fi

ENTRYPOINT ["bash", "-lc", "source /opt/rh/devtoolset-11/enable && source /opt/rh/rh-maven35/enable && source /opt/rh/rh-ruby27/enable && /opt/vespa-systemtests/lib/node_server.rb $NODE_SERVER_OPTS"]

