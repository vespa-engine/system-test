# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'test/unit'
require 'app_generator/container_app'
require 'app_generator/processing'
require 'app_generator/http'
require 'environment'
require_relative 'assertion_utils'

class ContainerAppGenTest < Test::Unit::TestCase
  include AssertionUtils

  def file(name)
    File.join(File.dirname(__FILE__), "#{name}")
  end

  def verify(expect, app)
    actual = app.services_xml
    File.open(file(expect + '.actual'), 'w') do |f|
      f.puts actual
    end
    assert(system("diff -u #{file expect + '.actual'} #{file expect}"))
  end

  def test_basic_container_app
    verify('basic_container.xml', ContainerApp.new)
  end

  def test_http_server
    actual = Container.new.
        http(Http.new.
                 server(Server.new('main-server', 4080))).
        to_xml('')

    expected_substr =
        '<http>
           <server id="main-server" port="4080" />
         </http>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_generic_component_with_config
    actual = Container.new.
        component(Component.new('my-id').
                      klass('com.yahoo.Foo').
                      bundle('my-bundle').
                      config(ConfigOverride.new('test-config').
                                 add('test-value', 0))).
        to_xml('')

    expected_substr =
        '<component bundle="my-bundle" class="com.yahoo.Foo" id="my-id">
           <config name="test-config">
             <test-value>0</test-value>
           </config>
         </component>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_basic_processing
    app = ContainerApp.new(false).container(Container.new.processing(
        Processing.new.chain(ProcessorChain.new.add(
        Processor.new("com.yahoo.vespatest.BasicProcessor")))))
    verify('basic_processing.xml', app)
  end

  def test_basic_processing_rendering
    app = ContainerApp.new(false).container(Container.new.processing(
        Processing.new.renderer(
          Renderer.new("hello", "com.yahoo.vespatest.HelloWorld"))\
        .chain(ProcessorChain.new.add(
          Processor.new("com.yahoo.vespatest.BasicProcessor")))))
    verify('basic_processing_rendering.xml', app)
  end

  def test_container_app
    verify('container.xml', ContainerApp.new(false)\
	.container(Container.new.baseport(5000).processing(
        Processing.new.renderer(
          Renderer.new("hello", "com.yahoo.vespatest.HelloWorld"))\
        .chain(ProcessorChain.new.add(
          Processor.new("com.yahoo.vespatest.BasicProcessor"))))))
  end

  def test_container_app_with_bindings
    verify('container_with_bindings.xml', ContainerApp.new(false)\
           .container(Container.new.handler(Handler.new("com.yahoo.vespatest.HelloWorld")\
             .binding("http://*/hello")\
             .binding("http://*/goodbye"))))
  end

  def test_container_app_with_concrete_docs
    actual =
        Container.new.
            concretedoc(ConcreteDoc.new('foo')).
            concretedoc(ConcreteDoc.new('bar').bundle('barbar').klass('ai.vespa.something.Bar')).
            to_xml('')
    expected_substr =
    '<container id="default" version="1.0">
       <document bundle="concretedocs" class="com.yahoo.concretedocs.Foo" type="foo" />
       <document bundle="barbar" class="ai.vespa.something.Bar" type="bar" />'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_docproc_and_search_in_same
    verify('docproc_and_search_in_same_container.xml', ContainerApp.new\
	.container(Container.new.search(Searching.new)\
          .docproc(DocumentProcessing.new\
            .chain(Chain.new.add(
              DocProc.new("com.yahoo.vespatest.WorstMusicDocProc")))))\
        .logserver("node1")\
        .slobrok("node1")\
        .search(SearchCluster.new("music").sd("music")))
  end

  def test_processing_and_search_in_same
    verify('processing_and_search_in_same_container.xml', ContainerApp.new\
	.container(Container.new.search(Searching.new)\
          .processing(Processing.new\
            .chain(ProcessorChain.new.add(
              Processor.new("com.yahoo.vespatest.SearchProcessor")))))\
        .logserver("node1")\
        .slobrok("node1")\
        .search(SearchCluster.new("music").sd("music")))
  end

  def test_basic_documentapi
    app = ContainerApp.new
            .container(Container.new.documentapi(ContainerDocumentApi.new
                         .feeder_options(FeederOptions.new.timeout(55.5))))
    verify('basic_documentapi.xml', app)
  end

  def test_access_log
    actual =
      Container.new.component(AccessLog.new("vespa").
                              fileNamePattern("#{Environment.instance.vespa_home}/logs/vespa/access/QueryAccessLog.%Y%m%d%H%M%S").
                              rotationInterval("0 1 ...")).
      to_xml("")

    expected_substr =
    "<container id=\"default\" version=\"1.0\">
       <accesslog fileNamePattern=\"#{Environment.instance.vespa_home}/logs/vespa/access/QueryAccessLog.%Y%m%d%H%M%S\" rotationInterval=\"0 1 ...\" type=\"vespa\" />"

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_request_filter_chain
    actual =
        Container.new.
            http(Http.new.
                     filter(HttpFilter.new('outer-filter', 'outer-class', 'outer-bundle')).
                     filter_chain(RequestFilterChain.new('request-chain').
                                      filter(HttpFilter.new('inner-filter')).
                                      filter(HttpFilter.new('outer-filter')).
                                      binding('http://binding1/').
                                      binding('http://binding2/'))).
            to_xml('')

    expected_substr =
    '<container id="default" version="1.0">
      <http>
        <filtering>
          <filter bundle="outer-bundle" class="outer-class" id="outer-filter" />
          <request-chain id="request-chain">
            <filter id="inner-filter" />
            <filter id="outer-filter" />
            <binding>http://binding1/</binding>
            <binding>http://binding2/</binding>
          </request-chain>
        </filtering>
      </http>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_filter_config
    actual =
        Container.new.http(Http.new.
                filter(HttpFilter.new("my-filter", nil, nil,
                           FilterConfig.new.add("name1", "value1").
                           add("name2", "value2")))).
            to_xml("")

    expected_substr =
    '<container id="default" version="1.0">
      <http>
        <filtering>
          <filter id="my-filter">
            <filter-config>
              <name1>value1</name1>
              <name2>value2</name2>
            </filter-config>
          </filter>
        </filtering>
      </http>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_jvm_options
    actual =
      Container.new.jvmgcoptions('-XX:+UseG1GC -XX:MaxTenuringThreshold=10').
        jvmoptions('-Dfoo=bar -Dvespa_foo=bar -Xms256m -Xms256m').
    to_xml("")

    expected_substr =
    '<container id="default" version="1.0">
      <nodes>
        <jvm gc-options="-XX:+UseG1GC -XX:MaxTenuringThreshold=10" options="-Dfoo=bar -Dvespa_foo=bar -Xms256m -Xms256m" />
        <node hostalias="node1" />
      </nodes>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end


  def test_cpu_pinning
    verify('basic_cpu_pinning.xml', ContainerApp.new.container(Container.new.cpu_socket_affinity(true)))
  end

  def assert_equal(exp, actual)
    assert(exp == actual, "Expected '#{exp}', but was '#{actual}'")
  end

end
