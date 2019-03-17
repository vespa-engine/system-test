# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class QrsObservability < IndexedSearchTest
  ClusterName = "search"
  QrsIndex = 0

  def qrs()
    vespa.container.values.first
  end

  def tld()
    vespa.search["search"].topleveldispatch["0"]
  end

  def tld_host_and_fs4_port
    "#{tld.name}:#{tld.ports[1]}"
  end

  def setup
    set_owner("nobody")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("sddocname:music", 10)
  end

  def assert_contains_packet(packet_name, xml)
    assert(/#{packet_name}:\s*[0-9A-F\n]{10,}/ =~ xml, xml)
  end

  def test_packets_in_trace
    query = "query=only un-cached packets are currently guaranteed to be added to the trace&noCache&traceLevel=10"
    xml = search(query).xmldata
    assert_contains_packet("QueryPacket", xml)
    assert_contains_packet("QueryResultPacket", xml)
  end

  def test_result_includes_verbose_query_dump
    xml = search("ignored&tracelevel=10").xmldata
    arbitrary_part_query_dump = "WORD[connectedItem=null"
    assert(xml, xml.include?(arbitrary_part_query_dump) )
  end

  def teardown
    stop
  end
end
