# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class ReindexingTest < IndexedStreamingSearchTest

  DOCUMENT_COUNT = 1000
  MUSIC_CLUSTER_ID = 'music'
  MOVIE_CLUSTER_ID = 'movie'
  MUSIC_DOC_TYPE = 'music'
  MOVIE_DOC_TYPE = 'movie'

  def setup
    set_owner('bjorncs')
  end

  def test_add_const_field
    set_description("test that adds a constant bool field to documents and verifies that the correct value is assigned during reindexing")
    testdir = selfdir + "add_const_field/"

    # First, we use the schema without the field const_bool
    system("cp #{testdir}item.0.sd #{dirs.tmpdir}item.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "item.sd")
    deploy_app(app)

    start

    puts "Feeding single document"
    doc = Document.new("id:test:item::0}")
    vespa.document_api_v1.put(doc)

    puts "Adding field to schema"
    # Add field const_bool to schema (outside of document)
    # This field should trivially be true for every document
    system("cp #{testdir}item.1.sd #{dirs.tmpdir}item.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "item.sd")
    deploy_output = redeploy(app)

    puts "Waiting for config to settle"
    wait_for_application(vespa.container.values.first,
                         deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))

    puts "Triggering reindexing"
    reindexing_timestamp = trigger_reindexing(app, "search", "item")

    puts "Waiting for reindexing to actually start"
    wait_for_reindexing_to_start("search", "item", reindexing_timestamp)

    puts "Waiting for all documents to have a index timestamp after #{reindexing_timestamp}"
    wait_for_reindexing_to_complete("search", "item", reindexing_timestamp, 1)

    puts "Feeding another document"
    doc = Document.new("id:test:item::1}")
    vespa.document_api_v1.put(doc)

    # Make sure both documents have the field const_bool set to true
    assert_hitcount("query=const_bool:true", 2)
    assert_hitcount("query=const_bool:false", 0)
  end

  def test_reindexing_with_multiple_content_clusters
    app = SearchApp.new.monitoring('vespa', 60).
        cluster(SearchCluster.new(MUSIC_CLUSTER_ID).sd(selfdir + 'music.sd')).
        cluster(SearchCluster.new(MOVIE_CLUSTER_ID).sd(selfdir + 'movie.sd')).
        container(Container.new('combinedcontainer').
            search(Searching.new).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new))
    deploy_app(app)
    start
    container_node = @vespa.container["combinedcontainer/0"]

    puts "Feeding #{MUSIC_DOC_TYPE} documents"
    music_file = generate_feed_file(container_node, MUSIC_DOC_TYPE)
    feed_and_wait_for_docs(MUSIC_DOC_TYPE, DOCUMENT_COUNT, { :file => music_file, :feed_node => container_node, :localfile => true })

    puts "Feeding #{MOVIE_DOC_TYPE} documents"
    movie_file = generate_feed_file(container_node, MOVIE_DOC_TYPE)
    feed_and_wait_for_docs(MOVIE_DOC_TYPE, DOCUMENT_COUNT, { :file => movie_file, :feed_node => container_node, :localfile => true })

    puts "Triggering reindexing"
    # Get the reindexing timestamp from MUSIC_CLUSTER_ID and MUSIC_DOC_TYPE
    reindexing_timestamp = trigger_reindexing(app, MUSIC_CLUSTER_ID, MUSIC_DOC_TYPE)

    puts "Waiting for reindexing to actually start"
    wait_for_reindexing_to_start(MUSIC_CLUSTER_ID, MUSIC_DOC_TYPE, reindexing_timestamp)
    wait_for_reindexing_to_start(MOVIE_CLUSTER_ID, MOVIE_DOC_TYPE, reindexing_timestamp)

    puts "Waiting for all documents to have a index timestamp after #{reindexing_timestamp}"
    wait_for_reindexing_to_complete(MUSIC_CLUSTER_ID, MUSIC_DOC_TYPE, reindexing_timestamp, DOCUMENT_COUNT)
    wait_for_reindexing_to_complete(MOVIE_CLUSTER_ID, MOVIE_DOC_TYPE, reindexing_timestamp, DOCUMENT_COUNT)
  end

  private
  def generate_feed_file(container_node, document_type)
    feed_file = "#{dirs.tmpdir}/#{document_type}.json"
    puts "Writing #{document_type} feed to #{feed_file}"
    container_node.write_document_operations(:put,
                                             { :fields => { :title => 'my title' } },
                                             "id:test:#{document_type}::",
                                             DOCUMENT_COUNT,
                                             feed_file)
    feed_file
  end


  private
  def trigger_reindexing(app, cluster_id, document_type)
    # Before triggering the reindexing, there is no reindexing status. So no point in checking it here.
    # Trigger reindexing
    response = http_request_post(URI(application_v2_url_prefix + 'reindex'), {})
    assert(response.code.to_i == 200, "Triggering reindexing of documents should give 200 response")

    # Now, we should get a reindexing status
    response = http_request(URI(application_v2_url_prefix + 'reindexing'), {})
    assert(response.code.to_i == 200, "Requesting reindexing status should give 200 response")
    reindexing_timestamp = get_json(response)['clusters'][cluster_id]['ready'][document_type]['readyMillis']
    assert(!reindexing_timestamp.nil?, "No reindexing timestamp obtained")

    # We have to redeploy the application to actually start the reindexing
    deploy_app(app)

    reindexing_timestamp
  end

  private
  def wait_for_reindexing_to_complete(cluster_id, document_type, reindexing_timestamp = nil, number_of_documents = nil)
    puts "Waiting for reindexing to complete for '#{document_type}@#{cluster_id}'"
    while true
      status = get_reindexing_status_from_cluster_controller(cluster_id, document_type)
      puts "Reindexing status for '#{document_type}@#{cluster_id}': #{status}"
      break if status and ['successful', 'failed'].include? status['state']
      sleep 5
    end
    assert('successful' == status['state'], "Reindexing should complete successfully")
    if reindexing_timestamp and number_of_documents
      assert_hitcount("#{document_type}_indexed_at_seconds:#{CGI::escape('<')}#{reindexing_timestamp/1000}&nocache", 0)
      assert_hitcount("#{document_type}_indexed_at_seconds:#{CGI::escape('>')}#{reindexing_timestamp/1000}&nocache", number_of_documents)
    end
  end

  private
  def get_reindexing_status_from_cluster_controller(cluster_id, document_type)
    status = vespa.clustercontrollers["0"].get_reindexing_json
    return nil if status.nil?
    cluster = status['clusters'][cluster_id]
    return nil if cluster.nil?
    return cluster['documentTypes'][document_type]
  end

  # Wait for reindexing after the given time to have started.
  def wait_for_reindexing_to_start(cluster_id, document_type, ready_millis)
    puts "Waiting for reindexing to start for '#{document_type}@#{cluster_id}', after #{Time.at(ready_millis / 1000)}"
    while true
      status = get_reindexing_status_from_cluster_controller(cluster_id, document_type)
      puts "Reindexing status for '#{document_type}@#{cluster_id}': #{status}" if Time.now.sec % 10 == 0
      break if status and status['startedMillis'] > ready_millis
      sleep 5
    end
  end

  private
  def application_v2_url_prefix
    tenant = use_shared_configservers ? @tenant_name : "default"
    application = use_shared_configservers ? @application_name : "default"
    cfg_hostname = vespa.nodeproxies.first[1].addr_configserver[0]
    "http://#{cfg_hostname}:19071/application/v2/tenant/#{tenant}/application/#{application}/environment/prod/region/default/instance/default/"
  end


end
