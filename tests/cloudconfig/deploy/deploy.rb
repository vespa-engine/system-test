# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'json'
require 'application_v2_api'
require 'environment'

class DeployV2 < CloudConfigTest

include ApplicationV2Api

  # TODO: @@vespa_home needs to be changed when running the test manually
  @@vespa_home = Environment.instance.vespa_home
  @@config_server_config_file = "#{@@vespa_home}/conf/configserver-app/configserver-config.xml"

  def setup
    set_owner("musum")
    set_description("Tests application REST API (v2)")
    @node = @vespa.nodeproxies.first[1]
    @hostname = @vespa.nodeproxies.first[0]
    @httpport = 19071
    @session_id = nil
    @original_config_server_config = write_default_config_server_config
    puts "original config server config: #{@original_config_server_config}"

    appdir = "#{CLOUDCONFIG_DEPLOY_APPS}/base"
    deploy(appdir, nil) # to initialize nodeproxies etc.
    delete_application_v2(@hostname, "default", "default")
    @tenant_name = "mytenant"
    create_tenant_and_wait(@tenant_name, @node.hostname)
    result = create_session(appdir, 0)
    @session_id = result["session-id"].to_i
    @application_name = "default"
    @environment = "prod"
    @region = "default"
    @instance = "default"
    @urischeme = https_client.scheme # TODO Inline as 'https' once TLS is enforced
  end

  def test_deploy_v2
    @node.execute("vespa-logctl -c configserver:com.yahoo.vespa.config.server.session debug=on", :exceptiononfailure => false)
    @session_id = @session_id+1
    @session_id = run_single_session(@session_id)
    @session_id = run_invalid_app(@session_id)
    @session_id = run_multiple_create_sessions(@session_id)
    @session_id = run_multiple_prepare_sessions(@session_id)
    @session_id = run_outdated_session_activation(@session_id)
    @session_id = run_activate_without_prepare(@session_id, @tenant_name)
    @session_id = run_serverdb_reuse_session_id(@session_id, @tenant_name)
    @session_id = run_configserver_restart(@session_id)
    @session_id = run_content_edit(@session_id)
    @session_id = run_content_status(@session_id)
    @session_id = run_zip_compression(@session_id)
    @session_id = run_application_list(@session_id)
    @session_id = run_delete_application(@session_id)
    @session_id = run_delete_tenant_with_application(@session_id)
    @session_id = run_application_content(@session_id)
    @session_id = run_create_from_application_url(@session_id)
    @session_id = run_deploy_pruning(@session_id)
    @session_id = run_create_two_sessions_activate_second_then_first(@session_id)
    @session_id = run_create_prepare_and_activate(@session_id)
  end

  def run_single_session(session_id=@session_id)
    set_description("Tests that deploying three sessions in a row works")
    session_id = deploy_and_activate_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    session_id = deploy_and_activate_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", session_id, 1338)
    deploy_and_activate_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_c", session_id, 1339)
  end

  def run_invalid_app(session_id=@session_id)
    set_description("Tests that deploying an invalid application package gives correct error code and error message")
    result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_invalid", session_id)
    result = put("#{result["prepared"]}?timeout=20.0")
    assert_equal(400, result.code.to_i)
    json = JSON.parse(result.body)
    assert_equal("INVALID_APPLICATION_PACKAGE", json["error-code"])
    message = json["message"]
    assert_match(/Invalid application: .*Invalid XML according to XML schema, error in services\.xml: element \"foo\" not allowed here/, message)
    assert_match(/\[4:11\]/, json["message"])
    next_session(session_id)
  end

  def run_multiple_create_sessions(session_id=@session_id)
    set_description("Tests creating multiple sessions in parallel and then preparing and activating one of them")
    session_a = session_id
    session_b = next_session(session_a)
    result_a = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_a)
    result_b = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", session_b)

    result_a = prepare_session(result_a, session_a)

    result_a = activate_session(result_a, session_a)
    assert_logd_config(1337)
    next_session(session_b)
  end

  def run_multiple_prepare_sessions(session_id=@session_id)
    set_description("Tests creating and preparing multiple sessions in parallel and then activate one of them")
    session_a = session_id
    session_b = next_session(session_a)
    result_a = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_a)
    result_b = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", session_b)

    result_a = prepare_session(result_a, session_a)
    result_b = prepare_session(result_b, session_b)

    result_a = activate_session(result_a, session_a)
    assert_logd_config(1337)
    next_session(session_b)
  end

  def run_activate_without_prepare(session_id=@session_id, tenant="default")
    set_description("Tests activating a session that has not been prepared")
    result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", session_id)
    result["activate"] = url_base_activate(session_id) + "?timeout=5.0"
    result = activate_session_fail(result, 400, /.*Session #{session_id} is not prepared/)
    next_session(session_id)
  end

  # Check that
  # #{Environment.instance.vespa_home}/var/db/vespa/config_server/serverdb/tenants/default/sessions/ is cleaned
  # when creating a session with the same session id that was used once in the past
  def run_serverdb_reuse_session_id(session_id=@session_id, tenant_name="default")
    # base app deployed in setup contains 'extra_file'
    deploy_and_activate_session("#{CLOUDCONFIG_DEPLOY_APPS}/base", session_id, 19080)
    assert_file_exists("#{@@vespa_home}/var/db/vespa/config_server/serverdb/tenants/#{tenant_name}/sessions/#{session_id}/extra_file")
    # Restart config server and delete zookeeper data so the next deploy
    # also will have session id 2
    restart_config_server(@node)
    # Zookeeper will be cleaned, so next deploy will get session id 2
    session_id = 2
    if (tenant_name != "default")
      create_tenant_and_wait(tenant_name, @node.hostname)
    end
    next_session_id = deploy_and_activate_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337) 
    assert_file_does_not_exist("#{@@vespa_home}/var/db/vespa/config_server/serverdb/tenants/#{tenant_name}/sessions/#{session_id}/extra_file")
    next_session_id
  end

  def run_configserver_restart(session_id=@session_id)
    set_description("Tests that restarting after upload, prepare, activate etc. works")
    expected_port = 19080
    session_id = deploy_and_activate_session("#{CLOUDCONFIG_DEPLOY_APPS}/base", session_id, expected_port) 
    restart_config_server(@node, :keep_zookeeper_data => true, :keep_configserver_data => true)
    assert_logd_config(expected_port)

    # create a new session, restart config server
    # try to prepare the session that was created
    result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id)
    restart_config_server(@node, :keep_zookeeper_data => true, :keep_configserver_data => true)
    result = prepare_session(result, session_id)
    assert_logd_config(expected_port)

    # create and prepare a new session, restart config server
    # try to activate the session prepared
    session_id = next_session(session_id)
    expected_port = 1337
    result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id)
    result = prepare_session(result, session_id)
    restart_config_server(@node, :keep_zookeeper_data => true, :keep_configserver_data => true)
    result = activate_session(result, session_id)
    assert_logd_config(expected_port)
    next_session(session_id)
  end

  def run_content_edit(session_id=@session_id)
    set_description("Tests that it is possible to edit an application packages content through edit interface")
    services = "services.xml"
    create_result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id)

    # Get deployed file
    output = read_application_file(session_id, services)
    assert_file_content_equal("#{CLOUDCONFIG_DEPLOY_APPS}/app_a/#{services}", output, "Files were not equal")

    # Put a new file that did not exist
    assert_put_application_file(session_id, "#{CLOUDCONFIG_DEPLOY_APPS}app_b/#{services}", services)

    output = read_application_file(session_id, services)
    assert_file_content_equal("#{CLOUDCONFIG_DEPLOY_APPS}/app_b/#{services}", output, "Files were not equal")

    # Create a directory
    result = create_application_dir(session_id, "files/")
    assert_not_error(result)
#    assert(!result.has_key?("error"))

    # Put a file in the directory
    assert_put_application_file(session_id, "#{CLOUDCONFIG_DEPLOY_APPS}/extra/test1.txt", "files/test1.txt")

    # Check directory listing
    result = list_application_dir(session_id, "files/")
#    assert_not_error(result)
#    assert(!result.has_key?("error"))
    assert_equal(result.size, 1)
    assert_equal(result[0], url_base_content(session_id) + "files/test1.txt")

    # Delete
    result = delete_application_file(session_id, "files/")
    assert(result.has_key?("message"))
    result = delete_application_file(session_id, "files/test1.txt")
    assert_not_error(result)
#    assert(!result.has_key?("error"))
    result = delete_application_file(session_id, "files/")
    assert_not_error(result)
#    assert(!result.has_key?("error"))

    assert_active_application(create_result, services, session_id)
  end

  def assert_active_application(create_result, services, session_id)
    # Test with active application
    prepare_result = prepare_session(create_result, session_id)
    activate_result = activate_session(prepare_result, session_id)
    output = read_application_file("active", services)
    assert_file_content_equal("#{CLOUDCONFIG_DEPLOY_APPS}/app_b/#{services}", output, "Files were not equal")
    next_session(session_id)
  end

  def run_content_status(session_id=@session_id)
    set_description("Tests that correct status is given for application package content")

    Struct.new("StatusResponse", :status, :md5, :name)
    services = "services.xml"
    create_result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id)

    # Get deployed file
    assert_status(session_id, services, create_status_response("new", "812e24f7ef19ff26ff7eba2aca76951c", services))

    # Put a new services file with changed content
    assert_put_application_file(session_id, "#{CLOUDCONFIG_DEPLOY_APPS}app_b/#{services}", services)
    assert_status(session_id, services, create_status_response("changed", "2b7268a18755fc8bd3a3a87de0d07115", services))

    # Put a file in the directory
    test_file = "files/test1.txt"
    assert_put_application_file(session_id, "#{CLOUDCONFIG_DEPLOY_APPS}/extra/test1.txt", test_file)
    assert_status(session_id, test_file, create_status_response("new", "14758f1afd44c09b7992073ccf00b43d", test_file))
    assert_not_error(create_application_dir(session_id, "files/subdir/"))
    test_file = "files/subdir/test2.txt"
    assert_put_application_file(session_id, "#{CLOUDCONFIG_DEPLOY_APPS}/extra/test1.txt", test_file)
    assert_status(session_id, test_file, create_status_response("new", "14758f1afd44c09b7992073ccf00b43d", test_file))
    assert_list_status(session_id, "files/", "false",
                       [create_status_response("new", "", "files/subdir"),
                        create_status_response("new", "14758f1afd44c09b7992073ccf00b43d", "files/test1.txt")])
    assert_list_status(session_id, "files/", "true",
                       [create_status_response("new", "", "files/subdir"),
                        create_status_response("new", "14758f1afd44c09b7992073ccf00b43d", "files/test1.txt"),
                        create_status_response("new", "14758f1afd44c09b7992073ccf00b43d", "files/subdir/test2.txt")])
    
    # Delete an existing file 
    test_file = "files/test1.txt"
    assert_not_error(delete_application_file(session_id, test_file))
    assert_status(session_id, test_file, create_status_response("deleted", "", test_file))

    # File that does not exist
    assert_not_error(get_content_status(session_id, "non-existing-file"))


    prepare_result = prepare_session(create_result, session_id)
    activate_result = activate_session(prepare_result, session_id)
    test_file = "files/subdir/test2.txt"
    assert_active_status(session_id, test_file, create_status_response("new", "14758f1afd44c09b7992073ccf00b43d", test_file))
    assert_active_status(session_id, services, create_status_response("changed", "2b7268a18755fc8bd3a3a87de0d07115", services))
    assert_active_list_status(session_id, "files/", "true",
                       [create_status_response("new", "", "files/subdir"),
                        create_status_response("new", "14758f1afd44c09b7992073ccf00b43d", "files/subdir/test2.txt")])
    next_session(session_id)
  end

  def run_zip_compression(session_id=@session_id)
    set_description("Tests that deploying an app with zip compresssion works")
    result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, "zip")
    result = prepare_session(result, session_id)
    result = activate_session(result, session_id)
    assert_logd_config(1337)
    next_session(session_id)
  end

  def run_outdated_session_activation(session_id=@session_id)
    set_description("Tests activating an outdated session created from a previously active application")
    session_a = session_id
    session_b = next_session(session_a)
    session_c = next_session(session_b)

    create_result_a = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_a)
    prepare_result_a = prepare_session(create_result_a, session_a)
    activate_session(prepare_result_a, session_a)

    # create and prepare from a, which is currently active, but do not activate yet
    result_b = create_session_url(application_url(@node.hostname, @tenant_name), session_b)
    result_b = prepare_session(result_b, session_b)
    # prepare and activate c
    deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_c", session_c, 1339)

    # try to activate b, which should give a conflict (status code 409)
    result = activate_session_fail(result_b, 409, /.*Cannot activate session #{session_b} because the currently active session \(#{session_c}\) has changed since session #{session_b} was created \(was #{session_a} at creation time\)/)
    assert_logd_config_v2(1339, @hostname, tenant_name, @application_name)

    # Deploying again should work
    session_d = next_session(session_c)
    deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", session_d, 1338)

    next_session(session_d)
  end

  def run_application_list(session_id=@session_id)
    apps = list_applications_v2(@hostname, @tenant_name)
    assert_equal(1, apps.length)
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    apps = list_applications_v2(@hostname, @tenant_name)
    assert_equal(1, apps.length)
    assert_equal(application_url(@hostname, @tenant_name), apps[0])
    session_id
  end

  def run_delete_application(session_id=@session_id)
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    apps = list_applications_v2(@hostname, @tenant_name)
    assert_equal(1, apps.length)
    delete_application_v2(@hostname, @tenant_name, @application_name)
    apps = list_applications_v2(@hostname, @tenant_name)
    assert_equal(0, apps.length)
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", session_id, 1338)
    apps = list_applications_v2(@hostname, @tenant_name)
    assert_equal(1, apps.length)
    assert_equal(application_url(@hostname, @tenant_name), apps[0])

    # Cleanup
    delete_application(@hostname, @tenant_name, @application_name)
    session_id
  end

  def run_delete_tenant_with_application(session_id=@session_id)
    create_tenant_and_wait(@tenant_name, @node.hostname)
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    apps = list_applications_v2(@hostname, @tenant_name)
    assert_equal(1, apps.length)
    
    response = delete_tenant(@tenant_name, @hostname)
    assert_equal(400, response.code.to_i)
    assert_equal("Cannot delete tenant 'mytenant', it has active applications: [mytenant.default]",
                 JSON.parse(response.body)["message"])
    session_id
  end

  def run_create_from_application_url(session_id=@session_id)
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    result = create_session_url(application_url(@node.hostname, @tenant_name, @application_name), session_id)
    # so that we can prepare the new session with the same host as the previous one
    # todo: change later to test with another host
    delete_application_v2(@hostname, @tenant_name, @application_name)
    result = prepare_session(result, session_id)
    result = activate_session(result, session_id)
    assert_logd_config_v2(1337, @hostname, tenant_name, @application_name)
    next_session(session_id)
  end

  def run_application_content(session_id=@session_id)
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    services = "services.xml"
    response = read_active_application_file(@node.hostname, @tenant_name, @application_name, services)
    assert_file_content_equal("#{CLOUDCONFIG_DEPLOY_APPS}/app_a/#{services}", response.body, "Files were not equal")
    output = JSON.parse(put_file("#{application_url(@node.hostname)}/content/#{services}", "#{CLOUDCONFIG_DEPLOY_APPS}/app_b/#{services}"))
    assert_equal("Method 'PUT' is not supported", output["message"])
    session_id
  end

  def run_deploy_pruning(session_id=@session_id)
    session_lifetime = 5 # seconds
    set_config_server_config({ "sessionLifetime" => session_lifetime })
    restart_config_server(@node, :keep_everything => true)
    session_id_a = session_id
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    assert_exists(session_id_a)

    session_id_b = session_id
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_b", session_id, 1338)
    assert_exists(session_id_b)

    session_id_c = session_id
    session_id = deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_c", session_id, 1339)
    sleep session_lifetime

    # Check that all sessions have been purged, except the active one
    wait_until_local_session_purged(session_id_a)
    wait_until_local_session_purged(session_id_b)
    assert_exists(session_id_c)

    set_config_server_config({ })
    restart_config_server(@node, :keep_everything => true)
    session_id
  end

  def run_create_two_sessions_activate_second_then_first(session_id=@session_id)
    set_description("Tests activating session with a lower session id than the last that was activated")
    first_session = session_id

    create_result = create_session("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", first_session)
    prepare_result = prepare_session(create_result, first_session)

    second_session = next_session(first_session)
    # create a second session, and activate it
    deploy_and_activate_session_v2("#{CLOUDCONFIG_DEPLOY_APPS}/app_c", second_session, 1339)
    third_session = next_session(second_session)

    # try to activate first session, which should fail, because config generation cannot go backwards
    result = activate_session_fail(prepare_result, 409, /Cannot activate session #{first_session} because the currently active session \(#{second_session}\) has changed since session #{first_session} was created \(was #{first_session - 1} at creation time\)/)
    assert_logd_config_v2(1339, @hostname, tenant_name, @application_name)
    next_session(second_session)
  end

  def run_prepare_and_activate_in_one_call(session_id=@session_id)
    set_description("Tests that preparing and activating in one call works")
    session_id = prepare_and_activate_one_call("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", session_id, 1337)
    next_session(session_id)
  end

  def run_create_prepare_and_activate(session_id)
    set_description("Tests that deploying with one REST API call (preapareandactivate) works")
    result = create_prepare_and_activate("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", @hostname, @tenant_name)
    assert_logd_config(1337)
    next_session(session_id)
  end

  def prepare_and_activate_one_call(appdir, session_id, expected_port)
    result = create_session(appdir, session_id)
    result = prepare_and_activate_session(result, session_id)

    assert_logd_config(expected_port)
    next_session(session_id)
  end

  def assert_put_application_file(session_id, appath, remotepath)
    result = put_application_file(session_id, appath, remotepath)
    assert(!result.has_key?("message"))
  end

  def read_application_file(session_id, path)
    url = URI("#{url_base_content(session_id)}#{path}")
    response = https_client.get(url.host, url.port, url.path, query: url.query)
    response.body
  end

  def assert_status(session_id, path, expected_response)
    assert_single_status(session_id, get_content_status(session_id, path), expected_response)
  end

  def assert_single_status(session_id, result, expected_response)
    expected_name = url_base_content(session_id) + expected_response[:name]
    assert_equal(expected_response[:status], result["status"])
    assert_equal(expected_response[:md5], result["md5"])
    assert_equal(expected_name, result["name"])
  end

  def assert_list_status(session_id, path, recursive, expected_responses)
    results = get_content_status(session_id, path, recursive)
    assert_list_status_lowlevel(session_id, recursive, results, expected_responses)
  end

  def assert_list_status_lowlevel(session_id, recursive, results, expected_responses)
    i = 0
    assert_equal(results.size, expected_responses.size)
    expected_responses.each { |response|
      assert_single_status(session_id, results[i], response)
      i = i + 1
    }
  end

  def get_content_status(session_id, path, recursive="false")
    url = URI("#{url_base_content(session_id)}#{path}?return=status&recursive=#{recursive}")
    response = https_client.get(url.host, url.port, url.path, query: url.query)
    JSON.parse(response.body)
  end

  def create_status_response(status, md5, name)
    Struct::StatusResponse.new(status, md5, name)
  end

  def put_application_file(session_id, appath, remotepath)
    output = put_file("#{url_base_content(session_id)}#{remotepath}", appath)
    JSON.parse(output)
  end

  def put_file(urlstring, appath)
    url = URI(urlstring)
    file_data = File.read(appath)
    response = https_client.put(url.host, url.port, url.path, file_data, query: url.query, headers: {'Content-Type' => 'application/x-www-form-urlencoded'})
    response.body
  end

  def create_application_dir(session_id, dirname)
    url = URI("#{url_base_content(session_id)}#{dirname}")
    response = https_client.put(url.host, url.port, url.path, nil, query: url.query)
    JSON.parse(response.body)
  end

  def delete_application_file(session_id, path)
    url = URI("#{url_base_content(session_id)}#{path}")
    response = https_client.delete(url.host, url.port, url.path, query: url.query)
    JSON.parse(response.body)
  end

  def list_application_dir(session_id, dirname, recursive = false)
    urlstring = "#{url_base_content(session_id)}#{dirname}"
    if recursive then
      urlstring += "?recursive=true"
    end
    url = URI(urlstring)
    response = https_client.get(url.host, url.port, url.path, query: url.query)
    JSON.parse(response.body)
  end

  def assert_not_error(json)
    assert(json.instance_of? Hash)
  end

  def assert_exists(session_id)
    assert(local_session_exists(session_id))
  end

  def assert_not_exists(session_id)
    !assert_exists(session_id)
  end

  def local_session_exists(session_id)
    exitcode, out = @node.execute("ls #{@@vespa_home}/var/db/vespa/config_server/serverdb/tenants/#{@tenant_name}/sessions/#{session_id}", { :exitcode => true, :noecho => true})
    exitcode == "0"
  end

  def wait_until_local_session_purged(session_id)
    # SessionsMaintainer is set to run every minute (see call to write_default_config_server_config in setup())
    session_exists = true
    # Wait for some time longer than maintainer interval, since config server might not have observed that session has been deactivated on first run
    190.times do |i|
      session_exists = local_session_exists(session_id)
      break if !session_exists
      sleep 1
    end
    raise "Timed out waiting for session #{session_id} to be purged" if session_exists
  end

  def create_session(*args)
    create_session_v2(@hostname, @tenant_name, *args)
  end

  def create_session_url(*args)
    create_session_v2_with_uri(@hostname, @tenant_name, *args)
  end

  def activate_session(*args)
    activate_session_v2(@hostname, @tenant_name, @application_name, @environment, @region, @instance, *args)
  end

  def activate_session_fail(prepare_result, response_code, expected_message)
    result = activate_session_common(prepare_result, response_code)
    assert_json_field_value_matches(result, "message", Regexp.new(expected_message))
    result
  end

  def prepare_session(*args)
    prepare_session_v2(@hostname, @tenant_name, *args)
  end

  def prepare_and_activate_session(*args)
    prepare_and_activate(@hostname, @tenant_name, *args)
  end

  def url_base_content(session_id)
    "#{@urischeme}://#{@hostname}:#{@httpport}/application/v2/tenant/#{@tenant_name}/session/#{session_id}/content/"
  end

  def url_base_activate(session_id)
    "http://#{@hostname}:#{@httpport}/application/v2/tenant/#{@tenant_name}/session/#{session_id}/active"
  end

  def assert_active_application(create_result, services, session_id)
    next_session(session_id)
  end

  def assert_active_status(session_id, path, expected_response)
    assert_single_status(session_id, get_content_status(session_id, path), expected_response)
  end

  def assert_active_list_status(session_id, path, recursive, expected_responses)
    assert_list_status(session_id, path, recursive, expected_responses)
  end

  def deploy_and_activate_session(appdir, session_id, expected_port)
    deploy_and_activate_session_v2(appdir, session_id, expected_port, @application_name, @tenant_name)
  end

  def assert_logd_config(expected_port)
    assert_logd_config_v2(expected_port, @hostname, @tenant_name, @application_name)
  end

  def write_default_config_server_config
    original_content = @node.readfile(@@config_server_config_file)
    set_config_server_config({})
    original_content
  end

  def set_config_server_config(fields_and_values)
    default_for_this_test = {
      "maintainerIntervalMinutes" => 1,
      "canReturnEmptySentinelConfig" => true,
    }

    merged = default_for_this_test.merge(fields_and_values)
    content = "<config name='cloud.config.configserver'>\n"
    merged.each{ |field, value|
      content = content + "<#{field}>#{value}</#{field}>\n"
    }
    content = content + "</config>\n"
    puts "Replacing config server config with " + content
    replace_config_server_config(content)
  end

  def replace_config_server_config(content)
    @node.writefile(content, @@config_server_config_file)
  end

  def assert_file_exists(file)
    assert("File #{file} does not exist", @node.readfile(file))
  end

  def assert_file_does_not_exist(file)
    assert("File #{file} exists", !@node.readfile(file))
  end

  def teardown
    stop
    @node.stop_base if @node
    puts "Stopping configserver"
    @node.stop_configserver if @node
    replace_config_server_config(@original_config_server_config)
    @dirty_environment_settings = true
  end

end
