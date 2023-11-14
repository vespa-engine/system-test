# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'

class SyncHttpHandler < SearchContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Check it's possible to deploy sync HTTP handlers")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.HelloWorld")
    @valgrind = false
    deploy_app(ContainerApp.new\
        .container(Container.new\
            .handler(Handler.new("com.yahoo.vespatest.HelloWorld")\
                .binding("http://*/hello"))))
    start
  end

  def test_synchttphandler
    result = search("/hello?name=Factory")
    assert "Hello, Factory!" == result.xmldata
  end

  def teardown
    stop
  end

end
