# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class RunFbench < IndexedOnlySearchTest

  def setup
    set_owner("toregge")
    set_description("Test vespa-fbench")
    @valgrind=false

    # Filenames
    @queryfile = "#{selfdir}/queries/query.txt"
    @fbench_output = @dirs.tmpdir + "fbench_out.txt"
    @num_queries = 4000

    container_cluster = Container.new("container").
      search(Searching.new).
      component(AccessLog.new("disabled"))
    deploy_app(SearchApp.new.
               sd("#{selfdir}/banana.sd").
               container(container_cluster))
    start
    @qrs = (vespa.qrserver.values.first or vespa.container.values.first)
    feed_and_wait_for_docs("banana", 2, :file => selfdir + "bananafeed.xml")
    @node = vespa.logserver
  end

  def initialize(*args)
    super(*args)
    @num_hosts = 1
  end

  def check_client(num_clients)
    result = @node.run_fbench(@queryfile, :clients => num_clients, :seconds => 30, :cycletime => 0, :qrserver => @qrs)
    assert(result[:failed] == 0, "Failed with #{num_clients} client")
  end

  def test_single_qrs
    # Check all queries are run
    result = @node.run_fbench(@queryfile, :seconds => 120, :reuse => 0, :cycletime => 0, :include_handshake => true, :qrserver => @qrs)
    assert_equal(@num_queries, result[:success] , "Not all queries runned")

    # Testing different number of clients
    check_client(1)
    check_client(10)
    check_client(100)
  end

  def check_log_field(log, name)
    assert(log.scan(/#{name}\s?:\s+[0-9]+/).size > 0, "Output missing #{name} field");
  end

  def test_fbench_log
    @node.run_fbench(@queryfile, :clients => 1, :seconds => 1, :reuse => 0, :output => @fbench_output, :get_extended => 1, :cycletime => 0, :qrserver => @qrs)

    # Assert output is written
    (exitcode, result) = @node.execute("cat #{@fbench_output}", {:exitcode => true})
    assert_equal(0, exitcode.to_i, "Output file is not created");

    # Assert URL is written
    assert( result.scan(/URL: \/search\/\?query=sddocname:banana/).size > 0 , "Output not printing URL")

    # Assert all extended info is printed
    puts "Result: " + result.to_s
    check_log_field(result, "NumHits")
    check_log_field(result, "NumFastHits")
    check_log_field(result, "QueryHits")
    check_log_field(result, "QueryOffset")
    check_log_field(result, "NumErrors")
    check_log_field(result, "SearchTime")
    check_log_field(result, "AttributeFetchTime")
    check_log_field(result, "FillTime")
    check_log_field(result, "DocsSearched")
    check_log_field(result, "NodesSearched")
    check_log_field(result, "FullCoverage")
  end

  def teardown
    stop
    `rm -fr #{@queryfile}_*splits #{@fbench_output}`
  end
end

class Fbench2 < IndexedOnlySearchTest

  def setup
    set_owner("toregge")
    set_description("Test vespa-fbench with multiple qrservers")
    @valgrind=false

    # Filenames
    @queryfile = "#{selfdir}/queries/query.txt"
    @fbench_output = @dirs.tmpdir + "fbench_out.txt"
    @num_queries = 4000

    c_cluster_a = Container.new('c-a').
                    search(Searching.new).
                    http(Http.new.server(Server.new('foo-server', 6180))).
                    documentapi(ContainerDocumentApi.new)
    c_cluster_b = Container.new('c-b').
                    search(Searching.new).
                    http(Http.new.server(Server.new('bar-server', 6190))).
                    documentapi(ContainerDocumentApi.new)
    deploy_app(SearchApp.new.
                 sd("#{selfdir}/banana.sd").
                 container(c_cluster_a).
                 container(c_cluster_b))
    start
    feed_and_wait_for_docs("banana", 2, :file => selfdir + "bananafeed.xml")
    @node = vespa.logserver
  end

  def test_multiple_qrs
    qrs0 = @vespa.container['c-a/0']
    qrs1 = @vespa.container['c-b/0']
    # Check all queries are run with two valid qrs servers
    result = @node.run_fbench(@queryfile, :seconds => -1, :reuse => 0, :multiple_qrs => 1, :cycletime => 0, :output => @fbench_output, :qrserver => qrs0, :qrserver2 => qrs1, :include_handshake => true)
    output = vespa.adminserver.readfile(@fbench_output)
    assert_equal(@num_queries, result[:success] , "Not all queries ran successfully, only #{result[:success]}/#{@num_queries} did. vespa-fbench output=#{output}")
  end

  def teardown
    stop
    `rm -fr #{@queryfile}_*splits #{@fbench_output}`
  end
end
