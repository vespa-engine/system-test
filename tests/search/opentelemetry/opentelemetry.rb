# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'
require 'search/opentelemetry/otelcolservice'

class OpenTelemetryTest < IndexedOnlySearchTest

  SHOW_TRACES = false

  def setup
    set_owner('toregge')
    @collector = nil
  end

  def teardown
    @collector.stop unless @collector.nil?
    @collector = nil
    stop
  end

  def can_share_configservers?
    false
  end

  def self.final_test_methods
    ['test_opentelemetry_smoketest']
  end

  def test_opentelemetry_smoketest
    set_description('Check that traces are propagated from vespa unit test binaries using opentelemetry-cpp sdk')
    node_proxy = vespa.nodeproxies.values.first
    workdir = "#{dirs.tmpdir}"
    command="mkdir -p #{workdir} && cd #{workdir} && #{Environment.instance.vespa_home}/bin/vespa-opentelemetry-test"
    (exitcode, output) = node_proxy.execute(command, {:exitcode => true, :exceptiononfailure => false, :stderr => true})
    assert_equal(0, exitcode.to_i)
  end

  def feed_doc(id, text)
    doc = Document.new(id).add_field("i1", text)
    vespa.document_api_v1.put(doc)
  end

  def test_basictraces
    set_description('Check that traces are propagated from vespa backend using opentelemetry sdk')
    workdir = "#{dirs.tmpdir}basictraces"
    remote_workdir = "#{workdir}-remote"
    node_proxy = vespa.nodeproxies.values.first
    set_feature_flag(node_proxy, 'opentelemetry-sdk', ['value' => {'enabled' => true, 'samplingRatio' => 1.0 }])
    @collector = OtelColService.new(self, tls_env, node_proxy, workdir, remote_workdir)
    @collector.write_host_hostname
    @collector.start
    deploy_app(SearchApp.new.
               cluster_name("basictraces").
               sd(selfdir + "test.sd"))
    start
    feed_doc('id:test:test::0', 'a a a a')
    feed_doc('id:test:test::1', 'a b a b')
    assert_hitcount({ 'yql' => "select * from sources * where i1 contains 'a'"}, 2)
    sleep 5
    vespa.stop_base
    vespa.stop_configservers
    @collector.stop
    traces = @collector.local_traces
    puts "---- start traces"
    num_resource_spans = 0
    num_scope_spans = 0
    num_spans = 0
    File.foreach(traces, chomp: true) do |line|
      json = JSON.parse(line)
      puts JSON.pretty_generate(json) if SHOW_TRACES
      resourceSpans = json['resourceSpans']
      unless resourceSpans.nil?
        resourceSpans.each do |resourceSpan|
          num_resource_spans = num_resource_spans + 1
          scopeSpans = resourceSpan['scopeSpans']
          unless scopeSpans.nil?
            scopeSpans.each do |scopeSpan|
              num_scope_spans = num_scope_spans + 1
              spans = scopeSpan['spans']
              unless spans.nil?
                spans.each do |span|
                  num_spans = num_spans + 1
                end
              end
            end
          end
        end
      end
    end
    puts "---- end traces, #{num_resource_spans} resource_spans, #{num_scope_spans} scope_spans, #{num_spans} spans"
  end

end
