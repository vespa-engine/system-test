# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'

class VespaDeploy < CloudConfigTest
  @app_path = nil
  @base_path = nil
  @node = nil
  @session_id = nil

  def setup
    set_owner("musum")
    set_description("Tests vespa-deploy tool")
    # todo: hack to get session id
    @session_id = get_generation(deploy(selfdir+"base")).to_i
    @app_path = "#{dirs.tmpdir}base"
    @node = vespa.adminserver
    @base_path = "http://#{@node.hostname}:19071/application/v2/tenant/default/"
    @session_path = "http://#{@node.hostname}:19071/application/v2/tenant/default/session"
    @tenant = "default"
  end

  def test_deploy_output
    # Test help command
    output = execute_and_get_output("vespa-deploy")
    assert_help_output(output)
    output = execute_and_get_output("vespa-deploy -h")
    assert_help_output(output)
    output = execute_and_get_output("vespa-deploy help")
    assert_help_output(output)

    output = execute_and_get_output("vespa-deploy help upload")
    assert_equal("Usage: vespa-deploy upload <application package>", output.chomp)

    output = execute_and_get_output("vespa-deploy help prepare")
    assert_equal("Usage: vespa-deploy prepare [<session_id> | <application package>]", output.chomp)

    output = execute_and_get_output("vespa-deploy help activate")
    assert_equal("Usage: vespa-deploy activate [<session_id>]", output.chomp)

    output = execute_and_get_output("vespa-deploy help fetch")
    assert_equal("Usage: vespa-deploy fetch <output directory>", output.chomp)

    # Test upload command
    (exitcode, output) = execute("vespa-deploy upload " + @app_path)
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    assert_equal(create_expected_upload_output, output)

    # Test upload command with port set
    (exitcode, output) = execute("vespa-deploy -p 19071 upload " + @app_path)
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    assert_equal(create_expected_upload_output, output)

    from_url = "#{@base_path}application/default/environment/prod/region/default/instance/default"
    (exitcode, output) = execute("cd #{@app_path}; vespa-deploy -F #{from_url} upload .")
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    assert_equal("Session #{@session_id} for tenant 'default' created.\n", output)

    # Test upload command with RPC port set (http port should still use port 19071)
    override_environment_setting(@node, "VESPA_CONFIGSERVER_RPC_PORT", "9999")
    (exitcode, output) = execute("vespa-deploy upload " + @app_path)
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    assert_equal(create_expected_upload_output, output)
    override_environment_setting(@node, "VESPA_CONFIGSERVER_RPC_PORT", "19070")
    @dirty_environment_settings = true

    (exitcode, output) = execute("cd #{@app_path}; vespa-deploy upload .")
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    assert_equal(create_expected_upload_output("."), output)

    (exitcode, output) = execute("vespa-deploy upload non-existing", { :stderr => true} )
    assert_equal(1, exitcode.to_i)
    assert_equal("Command failed. No such directory found: 'non-existing'", output.chomp)

    (exitcode, output) = execute("vespa-deploy -p 12345 upload " + @app_path, { :stderr => true })
    assert_equal(1, exitcode.to_i)
    assert_match(/Could not connect to.*12345/, output.chomp)

    # Test prepare command
    (exitcode, output) = execute("vespa-deploy prepare")
    assert_equal(0, exitcode.to_i)
    assert_match(create_expected_prepare_output, output)

    (exitcode, output) = execute("vespa-deploy prepare #{@session_id}")
    assert_equal(0, exitcode.to_i)
    assert_match(create_expected_prepare_output, output)

    (exitcode, output) = execute("vespa-deploy prepare " + @app_path)
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    expected = Regexp.union(Regexp.new(create_expected_upload_output), create_expected_prepare_output)
    assert_match(expected, output)

    (exitcode, output) = execute("cd #{@app_path}; vespa-deploy prepare .")
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    expected = Regexp.union(Regexp.new(create_expected_upload_output(".")), create_expected_prepare_output)
    assert_match(expected, output)

    (exitcode, output) = execute("vespa-deploy prepare non-existing", { :stderr => true })
    assert_equal(1, exitcode.to_i)
    assert_equal("Command failed. No directory or zip file found: 'non-existing'", output.chomp)

    # test with timeout
    (exitcode, output) = execute("vespa-deploy -t 30 prepare")
    assert_equal(0, exitcode.to_i)
    assert_match(create_expected_prepare_output, output)

    invalid_session_id = 9999
    (exitcode, output) = execute("vespa-deploy prepare #{invalid_session_id}", { :stderr => true })
    assert_equal(1, exitcode.to_i)
expected = <<EOS;
Preparing session #{invalid_session_id} using #{@session_path}/#{invalid_session_id}/prepared
Request failed. HTTP status code: 404
Local session 9999 for 'default' was not found
EOS
    assert_equal(expected, output)


    # Test activate command
    (exitcode, output) = execute("vespa-deploy prepare " + @app_path)
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    (exitcode, output) = execute("vespa-deploy activate")
    assert_equal(0, exitcode.to_i)
    assert_match(create_expected_activate_output, output)

    (exitcode, output) = execute("vespa-deploy prepare " + @app_path)
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    (exitcode, output) = execute("vespa-deploy activate #{@session_id}")
    assert_equal(0, exitcode.to_i)
    assert_match(create_expected_activate_output, output)

    assert_tenant_option_works

    # Test fetch command
    outdir = "#{dirs.tmpdir}fetchedapp"
    (exitcode, output) = execute("mkdir #{outdir}; vespa-deploy fetch #{outdir}")
    assert_equal(0, exitcode.to_i)
    assert_match(create_expected_fetch_output(outdir), output)
    assert_file_equal(@app_path, outdir, "services.xml")
    assert_file_equal(@app_path, outdir, "extra_file")

    (exitcode, output) = execute("vespa-deploy activate #{invalid_session_id}", { :stderr => true })
    assert_equal(1, exitcode.to_i)
expected = <<EOS;
Activating session #{invalid_session_id} using #{@session_path}/#{invalid_session_id}/active
Request failed. HTTP status code: 404
Local session 9999 for 'default' was not found
EOS
    assert_equal(expected, output)

    # Test with two servers, one of them is down, so should change to use the second one
    @session_id = @session_id + 1
    unavailable_server = "unavailablehost.trondheim.corp.yahoo.com"
    @node.set_addr_configserver([unavailable_server, @node.hostname])
    (exitcode, output) = execute("vespa-deploy prepare " + @app_path, { :stderr => true })
    assert_equal(0, exitcode.to_i)
    expected = <<EOS;
Uploading application '#{@app_path}' using.*
.*
.*
Retrying with another config server.*
Uploading application '#{@app_path}' using.*
Session #{@session_id} for tenant 'default' created..*
Preparing session #{@session_id} using.*\\n?.*
Session #{@session_id} for tenant 'default' prepared..*
EOS
    assert_match(Regexp.new(expected), output)
    @dirty_environment_settings = true
  end

  def test_deploy_app_with_symbolic_link
    (exitcode, output) = execute(@node, "cd #{dirs.tmpdir}; mkdir app_with_symbolic_link; cd app_with_symbolic_link; ln -s ../base/services.xml .; ls -l; cd ..; vespa-deploy -v prepare app_with_symbolic_link")
    assert_equal(0, exitcode.to_i)
  end

  def test_deploy_zip_file
    zip_file = "application.zip"
    (exitcode, output) = execute(@node, "cd #{dirs.tmpdir}base; zip -q #{zip_file} *; vespa-deploy prepare #{zip_file}")
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    expected = Regexp.union(Regexp.new(create_expected_upload_output(zip_file)), create_expected_prepare_output)
    assert_match(Regexp.new(expected), output)
  end

  def assert_help_output(output)
    assert_match("Usage: vespa-deploy", output)
    assert_match("Supported commands: ", output)
    assert_match("Supported options: ", output)
  end

  def assert_tenant_option_works
    tenant = "unknown"
    (exitcode, output) = execute("vespa-deploy -e #{tenant} upload " + @app_path, { :stderr => true })
    assert_equal(1, exitcode.to_i)
    expected = <<EOS;
Uploading application '#{@app_path}' using http://#{@node.hostname}:19071/application/v2/tenant/#{tenant}/session
Request failed. HTTP status code: 404
Tenant 'unknown' was not found.
EOS
    assert_equal(expected, output)

    (exitcode, output) = execute("vespa-deploy -e default upload #{@app_path}")
    assert_equal(0, exitcode.to_i)
    @session_id = @session_id + 1
    (exitcode, output) = execute("vespa-deploy -e default prepare")
    assert_equal(0, exitcode.to_i)
    assert_match(create_expected_prepare_output, output)
  end

  def create_expected_upload_output(path=@app_path)
    expected = <<EOS;
Uploading application '#{path}' using #{@session_path}
Session #{@session_id} for tenant '#{@tenant}' created.
EOS
  end

  def create_expected_fetch_output(outdir)
    expected = <<EOS;
Writing active application to #{outdir}
EOS
  end

  def create_expected_prepare_output()
    expected = <<EOS;
Preparing session #{@session_id} using #{@session_path}/#{@session_id}/prepared\\n?.*
Session #{@session_id} for tenant '#{@tenant}' prepared.
EOS
    Regexp.new(expected)
  end

  def create_expected_activate_output()
    expected = <<EOS;
Activating session #{@session_id} using #{@session_path}/#{@session_id}/active
Session #{@session_id} for tenant '#{@tenant}' activated.
Checksum:   \\w{32}
Timestamp:  \\d{13}
Generation: \\d+
EOS
    Regexp.new(expected)
  end

  def assert_file_equal(base, fetched, filename)
    base_content = File.new("#{base}/#{filename}", 'r').read
    fetched_content = @node.execute("cat #{fetched}/#{filename}")
    assert_equal(base_content, fetched_content)
  end

  def execute_and_get_output(command)
    (exitcode, output) = execute(command)
    output
  end

  def execute(command, params={})
    @node.execute(command, params.merge({ :exitcode => true }))
  end

  def teardown
    stop
  end

end
