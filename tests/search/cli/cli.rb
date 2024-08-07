# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Cli < IndexedStreamingSearchTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("mpolden")
    set_description("Test basic Vespa CLI functionality")
    @doc_id_prefix = "id:music:music::mydoc-"
  end

  def can_share_configservers?
    false
  end

  def create_app
    container = Container.new("default")
                  .http(Http.new.server(Server.new("default", vespa.default_document_api_port)))
                  .search(Searching.new)
                  .documentapi(ContainerDocumentApi.new)
    app = SearchApp.new
            .sd(SEARCH_DATA+"music.sd")
            .container(container)
    app_path = vespa.create_services_xml(app.services_xml)
    resolved_app = vespa.resolve_app(app_path, app.sd_files, {})
    remote_app_path = vespa.transfer_resolved(resolved_app, {})
    return remote_app_path
  end

  def container_url
    container = vespa.container["default/0"]
    http_port = container.ports_by_tag["http"]
    "https://#{container.hostname}:#{http_port}"
  end

  def generate_documents_file(doc_count, title)
    feed_file = "#{dirs.tmpdir}docs_#{doc_count}.json"
    vespa.adminserver.write_document_operations(:put,
                                                { :fields => { :title => title } },
                                                @doc_id_prefix,
                                                doc_count,
                                                feed_file,
                                                doc_count > 1)
    return feed_file
  end

  def print_output(stdout, stderr)
    puts "###### CLI stdout ######"
    puts stdout
    if !stderr.empty?
      puts "###### CLI stderr ######"
      puts stderr
    end
  end

  def deploy
    start
    cfg = hostlist.first
    remote_app_path = create_app
    status, stdout, stderr = vespa_cli("-t", "https://#{cfg}:19071", "deploy", "-w", "60", remote_app_path)
    print_output(stdout, stderr)
    assert_equal(0, status)
    # since we're deploying with cli we have to create the model explicitly
    vespa.create_model(vespa.adminserver.get_model_config({}, 2))
  end

  def feed(count, title)
    sub_cmd = count > 1 ? "feed" : "document"
    feed_file = generate_documents_file(count, title)
    status, stdout, stderr = vespa_cli("-t", container_url, sub_cmd, feed_file)
    print_output(stdout, stderr)
    assert_equal(0, status)
  end

  def get(id, expected_title)
    status, stdout, stderr = vespa_cli("-t", container_url, "document", "get", id)
    print_output(stdout, stderr)
    assert_equal(0, status)
    last_part = id.split(":").last
    expected = %|{
    "pathId": "/document/v1/music/music/docid/#{last_part}",
    "id": "#{id}",
    "fields": {
        "title": "#{expected_title}"
    }
}
|
    assert_equal(expected, stdout)
  end

  def query(query, expected_hit_count)
    status, stdout, stderr = vespa_cli("-t", container_url, "query", query)
    print_output(stdout, stderr)
    assert_equal(0, status)
    response = JSON.parse(stdout)
    assert_equal(expected_hit_count, response["root"]["fields"]["totalCount"])
  end

  def feed_and_get(count, title)
    feed(count, title)
    count.times do |n|
      get(@doc_id_prefix + n.to_s, title)
    end
  end

  def vespa_cli(*args)
    out_file = "#{dirs.tmpdir}/vespa_cli.out"
    err_file  = "#{dirs.tmpdir}/vespa_cli.err"
    cmd = "env "+
          "VESPA_CLI_DATA_PLANE_TRUST_ALL=true " +
          "VESPA_CLI_DATA_PLANE_CA_CERT_FILE=#{tls_env.ca_certificates_file} " +
          "VESPA_CLI_DATA_PLANE_CERT_FILE=#{tls_env.certificate_file} " +
          "VESPA_CLI_DATA_PLANE_KEY_FILE=#{tls_env.private_key_file} " +
          "vespa " + args.join(" ") + " 1> #{out_file} 2> #{err_file}"
    pid = vespa.adminserver.execute_bg(cmd)
    vespa.adminserver.waitpid(pid)
    status = $?.exitstatus
    return status, vespa.adminserver.readfile(out_file), vespa.adminserver.readfile(err_file)
  end

  def test_cli
    deploy
    # Feed and get single document with 'vespa document'
    feed_and_get(1, "Battery")
    query('"yql=select * from music where title contains \'battery\'"', 1)
    # Feed multiple documents with 'vespa feed' and get each with 'vespa document'
    feed_and_get(3, "Master of Puppets")
    query('"yql=select * from music where title contains \'master\'"', 3)
  end

  def teardown
    stop
  end

end
