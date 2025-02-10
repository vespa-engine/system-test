require 'search_test'
require 'app_generator/search_app'
require 'app_generator/storage_app'
require 'uri'

class DocumentApiV1Base < SearchTest

  def param_setup(params)
    @params = params
    setup_with_mode(indexed: params[:indexed])
  end

  def self.testparameters
    { 'INDEXED'    => { :indexed => true },
      'STORE_ONLY' => { :indexed => false } }
  end

  def setup_with_mode(indexed:)
    set_owner('vekterli')
    app = indexed ? indexed_app() : store_only_app()
    deploy_app(app)

    start

    # Just to make it possible to run test repeatedly without taking down cluster
    api_http_delete('/document/v1/storage_test/music/number/1/8')
    api_http_delete('/document/v1/storage_test/music/number/2/9')

    feed_single(1, 8)
  end

  def indexed_app
    SearchApp.new.sd(selfdir + 'music.sd').
      cluster_name('storage').
      num_parts(1).redundancy(1).ready_copies(1).
      storage(StorageCluster.new('storage', 1).distribution_bits(8))
  end

  def store_only_app
    StorageApp.new.default_cluster.sd(selfdir + 'music.sd').
      enable_document_api(FeederOptions.new.timeout(120)).
      transition_time(0).
      distribution_bits(8)
  end

  def api_http_post(path, content, headers={})
    vespa.document_api_v1.http_post(path, content, {}, headers)
  end

  def api_http_put(path, content, headers={})
    vespa.document_api_v1.http_put(path, content, {}, headers)
  end

  def api_http_delete(path)
    vespa.document_api_v1.http_delete(path)
  end

  def api_http_get(path)
    response = vespa.document_api_v1.http_get(path)
    vespa.document_api_v1.assert_response_ok(response)
    response.body
  end

  def feed_single(uid, doc_num, title = 'title', condition = nil, create = false)
    maybe_condition = condition.nil? ? "" : "?condition=#{CGI.escape(condition)}"
    maybe_create = create ? '"create":true,' : ""
    response = api_http_post("/document/v1/storage_test/music/number/#{uid}/#{doc_num}#{maybe_condition}",
                             "{#{maybe_create}\"fields\":{\"title\":\"#{title}\"}}")
    assert_json_string_equal(
      "{\"id\":\"id:storage_test:music:n=#{uid}:#{doc_num}\",\"pathId\":\"/document/v1/storage_test/music/number/#{uid}/#{doc_num}\"}",
      response)
    response
  end

  def assert_title(uid, doc_num, title)
    fields = JSON.parse(api_http_get("/document/v1/storage_test/music/number/#{uid}/#{doc_num}"))['fields']
    assert_equal({'title' => title}, fields)
  end

  def assert_not_found(uid, doc_num)
    response = vespa.document_api_v1.http_get("/document/v1/storage_test/music/number/#{uid}/#{doc_num}")
    assert_equal(404, response.code.to_i)
  end

  def assert_not_found_with_path(path)
    response = vespa.document_api_v1.http_get(path)
    assert_equal(404, response.code.to_i)
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
