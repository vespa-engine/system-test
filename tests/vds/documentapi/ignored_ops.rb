# Copyright Vespa.ai. All rights reserved.

require 'search_test'

class IgnoredOperationsTest < SearchTest

  def setup
    set_owner('vekterli')
    # Set up cluster to ignore a particular document title
    deploy_app(SearchApp.new.cluster(SearchCluster.new('test').
      sd(VDS + 'schemas/music.sd').
      doc_type('music', "music.title != 'danseband collection 1999'")))
    start
  end

  def teardown
    stop
  end

  def test_ignored_put_sets_http_response_header
    hdr_name = 'X-Vespa-Ignored-Operation'
    doc_api = vespa.document_api_v1
    # First, make sure _non-ignored_ operations do _not_ set an Ignored header.
    # Note: http_post() implicitly asserts that the response is 200 OK.
    res = doc_api.http_post('/document/v1/storage_test/music/number/1/1',
                            '{"fields":{"title":"4 hours of moose sounds"}}',
                            { :raw_response => true })
    assert res[hdr_name].nil?

    get_res = doc_api.http_get('/document/v1/storage_test/music/number/1/1')
    doc_api.assert_response_ok(get_res)

    res = doc_api.http_post('/document/v1/storage_test/music/number/1/2',
                            '{"fields":{"title":"danseband collection 1999"}}',
                            { :raw_response => true })
    assert_equal('true', res[hdr_name])
    # Should not have been inserted
    get_res = doc_api.http_get('/document/v1/storage_test/music/number/1/2')
    assert_equal(404, get_res.code.to_i)
  end

end
