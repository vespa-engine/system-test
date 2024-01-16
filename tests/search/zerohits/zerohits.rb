# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class ZeroHits < IndexedStreamingSearchTest

  def setup
    set_owner('arnej')
    set_description('Do a query where hits=0')
    deploy_app(SearchApp.new.sd(selfdir+'music.sd'))
    start
  end

  def test_zerohits
    feed_and_wait_for_docs('music', 2, :file => selfdir+'input.xml')

    puts 'Running query to see that doc is searchable'
    assert_hitcount('query=metallica', 1)
    assert_hitcount('query=metallica&hits=0', 1)

    puts 'Search for docs in the normal way'
    check_fields = [ "title", "artist"]
    assert_result('query=metallica', selfdir+'1m.result.json', nil, check_fields)
    assert_result('query=cure',      selfdir+'1c.result.json', nil, check_fields)

    puts 'Search for docs with zero hits'
    assert_result('query=metallica&hits=0', selfdir+'0.result.json')
    assert_result('query=metallica&hits=0', selfdir+'0.result.json')
    assert_result('query=metallica&hits=0&nocache', selfdir+'0.result.json')

    assert_result('query=cure&hits=0', selfdir+'0.result.json')
    assert_result('query=cure&hits=0', selfdir+'0.result.json')
    assert_result('query=cure&hits=0&nocache', selfdir+'0.result.json')

  end

  def teardown
    stop
  end

end
