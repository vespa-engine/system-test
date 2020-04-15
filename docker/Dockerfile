FROM vespaengine/vespa
  
RUN yum -y install rh-maven35 libxml2-devel rh-ruby23 rh-ruby23-rubygems-devel rh-ruby23-ruby-devel rh-ruby23-rubygem-net-telnet devtoolset-9-gcc-c++ git && \
    source /opt/rh/rh-ruby23/enable && \
    source /opt/rh/devtoolset-9/enable && \
    gem install libxml-ruby gnuplot distribution test-unit builder concurrent-ruby && \
    alternatives --set java java-11-openjdk.x86_64 && \
    alternatives --set javac java-11-openjdk.x86_64 && \
    yum --enablerepo='*' clean all 

ENV RUBYLIB=/opt/vespa-systemtests/lib:/opt/vespa-systemtests/tests

COPY . /opt/vespa-systemtests

RUN source /opt/rh/rh-ruby23/enable && \
    bash -c '/usr/bin/env USER=root /opt/vespa-systemtests/lib/node_server.rb & export PID=$!; sleep 3; kill -9 $PID'

ENTRYPOINT ["bash", "-lc", "source /opt/rh/rh-maven35/enable && source /opt/rh/rh-ruby23/enable && /opt/vespa-systemtests/lib/node_server.rb $NODE_SERVER_OPTS"]

