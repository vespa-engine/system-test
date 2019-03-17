# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class RunFbench < IndexedSearchTest

  def setup
    set_owner("toregge")
    set_description("Test vespa-fbench")
    @valgrind=false

    # Filenames
    @queryfile = "#{selfdir}/queries/query.txt"
    @fbench_output = @dirs.tmpdir + "fbench_out.txt"
    @num_queries = 4000

    deploy_app(SearchApp.new.sd("#{selfdir}/banana.sd"))
    start
    feed_and_wait_for_docs("banana", 2, :file => selfdir + "bananafeed.xml")
    @node = vespa.logserver
  end

  def initialize(*args)
    super(*args)
    @num_hosts = 1
  end

  def check_client(num_clients)
    result = @node.run_fbench(@queryfile, :clients => num_clients, :seconds => 30, :cycletime => 0)
    assert(result[:failed] == 0, "Failed with #{num_clients} client")
  end

  def test_single_qrs
    # Check all queries are run
    result = @node.run_fbench(@queryfile, :seconds => 120, :reuse => 0, :cycletime => 0)
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
    @node.run_fbench(@queryfile, :clients => 1, :seconds => 1, :reuse => 0, :output => @fbench_output, :get_extended => 1, :cycletime => 0)

    # Assert output is written
    (exitcode, result) = @node.execute("cat #{@fbench_output}", {:exitcode => true})
    assert_equal(0, exitcode.to_i, "Output file is not created");

    # Assert URL is written
    assert( result.scan(/URL: \/search\/\?query=sddocname:banana/).size > 0 , "Output not printing URL")

    # Assert all extended info is printed
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

class Fbench2 < IndexedSearchTest

  def setup
    set_owner("toregge")
    set_description("Test vespa-fbench with multiple qrservers")
    @valgrind=false

    # Filenames
    @queryfile = "#{selfdir}/queries/query.txt"
    @fbench_output = @dirs.tmpdir + "fbench_out.txt"
    @num_queries = 4000

    qrscl1 = QrserverCluster.new
    qrscl1.node(:hostalias => "node1")
    qrscl1.node(:hostalias => "node2")
    qrservers = Qrservers.new
    qrservers.qrserver(qrscl1)
    deploy_app(SearchApp.new.sd("#{selfdir}/banana.sd").
               num_hosts(@num_hosts).
               qrservers(qrservers))
    start
    feed_and_wait_for_docs("banana", 2, :file => selfdir + "bananafeed.xml")
    @node = vespa.logserver
  end

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def test_multiple_qrs
    # Check all queries are run with two valid qrs servers
    result = @node.run_fbench(@queryfile, :seconds => -1, :reuse => 0, :multiple_qrs => 1, :cycletime => 0, :output => @fbench_output, :qrserver => vespa.qrserver["0"], :qrserver2 => vespa.qrserver["1"])
    output = vespa.adminserver.readfile(@fbench_output)
    assert_equal(@num_queries, result[:success] , "Not all queries ran successfully, only #{result[:success]}/#{@num_queries} did. vespa-fbench output=#{output}")
  end

  def teardown
    stop
    `rm -fr #{@queryfile}_*splits #{@fbench_output}`
  end
end
