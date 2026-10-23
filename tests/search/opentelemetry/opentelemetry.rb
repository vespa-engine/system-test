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

  def read_traces
    traces = []
    puts "---- start traces" if SHOW_TRACES
    File.foreach(@collector.local_traces, chomp: true) do |line|
      json = JSON.parse(line)
      puts JSON.pretty_generate(json) if SHOW_TRACES
      traces.push(json)
    end
    puts "---- end traces" if SHOW_TRACES
    traces
  end

  def process_traces(traces)
    num_resource_spans = 0
    num_scope_spans = 0
    num_spans = 0
    @proton_process_starting = 0
    @proton_process_starting_started_proton = 0
    traces.each do |json|
      resourceSpans = json['resourceSpans']
      unless resourceSpans.nil?
        resourceSpans.each do |resourceSpan|
          num_resource_spans += 1
          scopeSpans = resourceSpan['scopeSpans']
          unless scopeSpans.nil?
            scopeSpans.each do |scopeSpan|
              num_scope_spans += 1
              spans = scopeSpan['spans']
              unless spans.nil?
                spans.each do |span|
                  if span['name'] == 'Proton process starting'
                    @proton_process_starting += 1
                    events = span['events']
                    unless events.nil?
                      events.each do |event|
                        if event['name'] == 'Started proton'
                          @proton_process_starting_started_proton += 1
                        end
                      end
                    end
                  end
                  num_spans += 1
                end
              end
            end
          end
        end
      end
    end
    puts "#{num_resource_spans} resource_spans, #{num_scope_spans} scope_spans, #{num_spans} spans"
    puts "#{@proton_process_starting} proton_process_starting, #{@proton_process_starting_started_proton} proton_process_starting_started_proton"
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
    traces = read_traces
    process_traces(traces)
    assert_equal(1, @proton_process_starting)
    assert_equal(1, @proton_process_starting_started_proton)
  end

end
