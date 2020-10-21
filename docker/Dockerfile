FROM vespaengine/vespa
  
RUN yum -y install rh-maven35 libxml2-devel rh-ruby25 rh-ruby25-rubygems-devel rh-ruby25-ruby-devel rh-ruby25-rubygem-net-telnet devtoolset-9-gcc-c++ git && \
    source /opt/rh/rh-ruby25/enable && \
    source /opt/rh/devtoolset-9/enable && \
    gem install libxml-ruby gnuplot distribution test-unit builder concurrent-ruby && \
    alternatives --set java java-11-openjdk.x86_64 && \
    alternatives --set javac java-11-openjdk.x86_64 && \
    yum --enablerepo='*' clean all 

ENV RUBYLIB=/opt/vespa-systemtests/lib:/opt/vespa-systemtests/tests

COPY . /opt/vespa-systemtests

RUN /opt/vespa-systemtests/docker/include/setup-tls.sh

ENV VESPA_TLS_CONFIG_FILE=/opt/vespa/conf/vespa/tls/tls_config.json

ENTRYPOINT ["bash", "-lc", "source /opt/rh/rh-maven35/enable && source /opt/rh/rh-ruby25/enable && /opt/vespa-systemtests/lib/node_server.rb $NODE_SERVER_OPTS"]

