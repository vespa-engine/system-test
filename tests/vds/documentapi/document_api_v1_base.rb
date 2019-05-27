require 'multi_provider_storage_test'
require 'uri'

class DocumentApiV1Base < MultiProviderStorageTest

  def setup
    set_owner('valerijf')

    deploy_app(default_app.sd(selfdir+'music.sd').distribution_bits(8))

    start

    # Just to make it possible to run test repeatedly without taking down cluster
    vespa.document_api_v1.http_delete('/document/v1/storage_test/music/number/1/8')
    vespa.document_api_v1.http_delete('/document/v1/storage_test/music/number/2/9')

    feed_single(1, 8)
  end

  def self.testparameter
    { 'PROTON' => { :provider => 'PROTON' } }
  end

  def api_http_post(path, content, headers={})
    vespa.document_api_v1.http_post(path, content, {}, headers)
  end

  def api_http_put(path, content, headers={})
    vespa.document_api_v1.http_put(path, content, {}, headers)
  end

  def api_http_get(path)
    response = vespa.document_api_v1.http_get(path)
    vespa.document_api_v1.assert_response_ok(response)
    response.body
  end

  def feed_single(uid, doc_num, title = 'title')
    response = api_http_post("/document/v1/storage_test/music/number/#{uid}/#{doc_num}", "{\"fields\":{\"title\":\"#{title}\"}}")
    assert_json_string_equal(
      "{\"id\":\"id:storage_test:music:n=#{uid}:#{doc_num}\",\"pathId\":\"/document/v1/storage_test/music/number/#{uid}/#{doc_num}\"}",
      response)
    response
  end

  def assert_fails_with_precondition_violation
    begin
      yield
      flunk('Expected operation to fail with an exception')
    rescue HttpResponseError => e
      assert_equal(412, e.response_code) # HTTP 412 Precondition Failed
    end
  end

  def teardown
    stop
  end
end

