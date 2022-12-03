# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'tempfile'
require 'drb'
require 'fileutils'
require 'optparse'
require 'rexml/document'
require 'socket'
require 'net/http'
require 'vespa_model'
require 'node_server_interface'
require 'node_proxy'
require 'doc_reader'
require 'document'
require 'documentupdate'
require 'sentinel'
require 'hit'
require 'hits'
require 'resultset'
require 'tenant_rest_api'
require 'tensor_result'
require 'vespa_hosts'
require 'vespa_coredump'
require 'rpc/rpcwrapper'
require 'nodetypes/feeder'
require 'nodetypes/vespa_node'
require 'nodetypes/container_node'
require 'nodetypes/query_loader'
require 'nodetypes/storage'
require 'nodetypes/storagenode'
require 'nodetypes/adminserver'
require 'nodetypes/configserver'
require 'nodetypes/contentclustercontroller'
require 'nodetypes/logserver'
require 'nodetypes/qrserver'
require 'nodetypes/vdsnode'
require 'nodetypes/distributor'
require 'nodetypes/search'
require 'nodetypes/group'
require 'nodetypes/searchnode'
require 'nodetypes/fleetcontroller'
require 'nodetypes/slobrok'
require 'nodetypes/metricsproxy_node'
require 'executeerror'
require 'environment'


# The TestBase module contains methods that share common vespa-specific
# functionality for testcases. These methods are typically shortcuts for
# feeding data, copying plugins and searching. This module is included
# in the TestCase class, which all other testcases inherit from.
module TestBase
  include TenantRestApi
  attr_accessor :vespa, :tenant_name, :application_name, :use_shared_configservers, :configserverhostlist

  def self.existing_of(dir1, dir2)
    if File.exists?(dir1)
      return dir1;
    else
      return dir2;
    end
  end

  DRUBY_REMOTE_PORT = 27183

  # absolute path to the systemtests/tests/
  INSTALL_DIR = $:.find {|path| path =~ /systemtests.*\/tests$/} || ""

  # absolute path to the system-test/tests/
  REPO_DIR = $:.find {|path| path =~ /system-test.*\/tests/} || ""

  # absolute path to systemtests/tests/vds/
  VDS = existing_of(INSTALL_DIR + "/vds/", REPO_DIR + "/vds/")

  # absolute path to systemtests/tests/search/
  SEARCH = existing_of(INSTALL_DIR + "/search/", REPO_DIR + "/search/")

  # absolute path to systemtests/tests/docproc/
  DOCPROC = existing_of(INSTALL_DIR + "/docproc/", REPO_DIR + "/docproc/")

  # absolute path to systemtests/tests/cloudconfig/
  CLOUDCONFIG = existing_of(INSTALL_DIR + "/cloudconfig/", REPO_DIR + "/cloudconfig/")

  # absolute path to systemtests/tests/performance/
  PERFORMANCE = existing_of(INSTALL_DIR + "/performance/", REPO_DIR + "/performance/")

  # absolute path to tests/search/data
  SEARCH_DATA = existing_of(INSTALL_DIR + "/search/data/", REPO_DIR + "/search/data/")

  # Timeout-multiplier when running test through valgrind
  VALGRIND_TIMEOUT_MULTIPLIER = 20

  # Timeout-multipler when running test with sanitizer
  SANITIZERS_TIMEOUT_MULTIPLIER = 5

  # Max query timeout allowed by QRS.
  MAX_QUERY_TIMEOUT=600

  RFC2396_PARSER = URI::RFC2396_Parser.new

  bundles = []

  def self.testdata_url(hostname)
    return Environment.instance.testdata_url(hostname)
  end

  TESTDATA_URL = testdata_url(`hostname`.chomp)

  def init_vespa_model(me, vespa_version)
    @vespa = VespaModel.new(me, vespa_version)
    @vespa.init_nodeproxies
  end

  # Creates an instance of VespaModel, then deploys _application_ on the adminserver.
  # Search definition files can be substituted by specifying _sdfile_
  # (string or an array of strings).
  def resolve_app(application, sdfile=nil, params={})
    return @vespa.resolve_app(application, sdfile, params)
  end

  def transfer_app(application, sdfile=nil, params={})
    resolved_app = @vespa.resolve_app(application, sdfile, params)
    return @vespa.transfer_resolved(resolved_app, params)
  end

  def deploy(application, sdfile=nil, params={})
    return @vespa.deploy(application, sdfile, params)
  end

  def deploy_transfered(app_handle, params={})
    return @vespa.deploy_transfered(app_handle, params)
  end

  def deploy_resolved(application, params={})
    app_handle = @vespa.transfer_resolved(application, params)
    return @vespa.deploy_transfered(app_handle, params)
  end

  # Deploys an application that is installed on the test nodes
  def deploy_local(appdir, appname, params={})
    @vespa.deploy_local(appdir, appname, @vespa.nodeproxies[hostlist.first], selfdir, params)
  end

  def deploy_mock(vespa)
    @vespa = vespa
  end

  # Deploys an application represented by the given app instance.
  def deploy_app(app, deploy_params = {})
    deploy_generated(app.services_xml, app.sd_files,
                     deploy_params.merge(app.deploy_params), app.hosts_xml, nil, app.validation_overrides_xml)
  end

  # Deploys an application with a provided services.xml buffer
  def deploy_generated(applicationbuffer, sdfile=nil, params={}, hostsbuffer=nil, deploymentbuffer=nil, validation_overridesbuffer=nil)
    @vespa.deploy_generated(applicationbuffer, sdfile, params, hostsbuffer, deploymentbuffer, validation_overridesbuffer)
  end

  # Deploys an application using a sdfile located on the first remote node
  # with Vespa installed. Typically used in singlenode setups for testing
  # sdfiles that are a part of the Vespa installation.
  def deploy_remote_sdfile(application_package, sd_filename, params={})
    remotehost = hostlist.first
    proxy = @vespa.nodeproxies[remotehost]
    content = proxy.readfile(sd_filename)
    local_sdfilename = selfdir+File.basename(sd_filename)
    File.open(local_sdfilename, "w") do |file|
      file.write(content)
    end
    deploy(application_package, local_sdfilename, params)
    FileUtils.rm_rf(local_sdfilename)
  end

  def deploy_expand_vespa_home(app)
    deploy(app, nil, :sed_vespa_services => "sed 's,\\$VESPA_HOME,#{Environment.instance.vespa_home},g'")
  end

  # :call-seq:
  #   create_resultset(xmlfile)  -> Resultset
  #
  # Returns a resultset object built from _xmlfile_.
  def create_resultset(xmlfile, query = nil)
    return Resultset.new(File.read(xmlfile), query, nil)
  end

  def calc_instrumented_timeout(timeout)
    return timeout * VALGRIND_TIMEOUT_MULTIPLIER if @valgrind
    return timeout * SANITIZERS_TIMEOUT_MULTIPLIER if has_active_sanitizers
    return timeout
  end

  def calculateQueryTimeout(timeout)
      timeout = calc_instrumented_timeout(timeout)
      if timeout < MAX_QUERY_TIMEOUT
          return timeout
      end
      return MAX_QUERY_TIMEOUT
  end

  # Convenience method for creating a bundle which only consists of a single .java-file
  def add_bundle(sourcefile, params={})
    classname = File.basename(sourcefile, ".java")
    pkgline = `grep ^package #{sourcefile}`
    if !pkgline or pkgline == ""
      raise "the searcher file (#{sourcefile}) must contain a package declaration"
    end
    pkgpath = pkgline.split()[1].chop;
    add_bundle_dir(sourcefile, pkgpath + "." + classname, params)
  end

  # Builds and installs a bundle located in the given _sourcedir_(string). The sourcedir must be a
  # correct java source hierarcy (i.e. containing src/main/java/com/yahoo/...)
  def add_bundle_dir(sourcedir, bundlename, params={})
    @vespa.add_bundle(sourcedir, bundlename, params)
  end

  def clear_bundles()
    @vespa.clear_bundles()
  end

  def compile_bundles(adminserver)
    @vespa.compile_bundles(adminserver)
  end

  def url_escape_q(q)
    uri_escape(q, /[{};"<>\[\]@\*\|\(\)\\]?/)
  end

  def uri_escape(uri, regex)
    RFC2396_PARSER.escape(uri, regex)
  end

  def search_with_timeout(timeout, query, qrserver_id=0, requestheaders = {}, verbose = false, params = {})
    timeout = calculateQueryTimeout(timeout)
    query = query + "&timeout=" + timeout.to_s
    search_base(query, qrserver_id, requestheaders, verbose, params)
  end

  # Performs _query_ on qrserver[qrserver_id] and returns the result.
  def search(query, qrserver_id=0, requestheaders = {}, verbose = false, params = {})
    search_with_timeout(10, query, qrserver_id, requestheaders, verbose, params)
  end

  def search_base(query, qrserver_id=0, requestheaders = {}, verbose = false, params = {})
    # insert / if missing
    if query.scan(/^\//).empty?
      # insert ? if missing
      if query.scan(/^\?/).empty?
        # insert query= if missing
        if (query.scan(/query=/).empty? and query.scan(/yql=/).empty?)
          query = "query=" + query
        end
        query = "?" + query
      end
      query = "/search/" + query
    else
      if (query.scan(/^\/search/).empty? and !query.scan(/^\/\?query/).empty?)
        query = "/search" + query
      end
    end

    query = url_escape_q(query)
    cluster = params[:cluster]
    server_id = qrserver_id.to_s
    if cluster
      # Note: Lookup of vespa.qrs works even if no cluster exists (see initializing code for vespa.qrs in vespa_model.rb)
      container = (vespa.qrs[cluster].qrserver[server_id] || vespa.container[cluster + "/container." + server_id])
    else
      container = (vespa.qrserver[server_id] || vespa.container.values.first)
    end

    result = container.search(to_utf8(query), 0, requestheaders, verbose, params)

    # write result to tmpfile, often used for debugging while writing testcases
    File.open("#{Environment.instance.tmp_dir}/lastresult.xml", "w") do |file|
      file.print(result.xmldata)
    end
    result
  end

  # Saves the result of _query_ from qrserver[qrserver_id] to file _file_.
  def save_result(query, file, qrserver_id=0)
    result = search(query, qrserver_id)
    File.open(file, "w") do |file|
      file.print(result.xmldata)
    end
    return result
  end

  # Computes correct timeout does the same as save_result.
  def save_result_with_timeout(timeout, query, file, qrserver_id=0)
    result = search_with_timeout(timeout, query, qrserver_id)
    File.open(file, "w") do |file|
      file.print(result.xmldata)
    end
    return result
  end

  # Deploys the application in selfdir + app.
  def deploy_application
    deploy(selfdir + "app")
  end

  # Starts vespa and waits until it is ready.
  def start(timeout=180)
    if vespa then
      @stop_timestamp = nil
      vespa.start
      wait_until_all_services_up(timeout)
    end
    @stopped = false
  end

  def can_check_for_hanging_config_server
    @vespa.logserver && @vespa.configservers && !@vespa.configservers.empty?
  end

  def check_for_hanging_config_server_HACK
    begin
      return if !can_check_for_hanging_config_server

      matches = @vespa.logserver.log_matches('ConfigurationRuntimeException')
      return if matches == 0

      output("Config server might be hanging. Dumping process stack " +
             "(see Vespa log for output)")
      @vespa.configservers.each do |idx, server|
        server.execute("pkill -QUIT -u yahoo -f 'configserver'")
      end
    rescue => e
      output("Got exception while checking if config server is hanging: #{e}")
    end
  end

  def stop_impl
    path = File.join(@dirs.tmpdir, 'query_result.log')
    if File.exist?(path)
      attach_to_factory_report(path)
    end

    if @vespa
      check_for_hanging_config_server_HACK
      ##
      ##   enable next line to find which processes use lots of memory:
      ##   vespa.adminserver.execute("ps xgauww | sort +4n") if vespa.adminserver
      ##
      @stop_timestamp = Time.now.to_f
      output("Stopping vespa")
      vespa.stop
      output("Vespa Stopped, Cleaning vespa")
      vespa.clean
      output("Vespa cleaned")
    else
      output("no vespa deployed, skipping stop and clean")
    end
    @stopped = true
  end

  # Stops vespa and cleans up.
  def stop
    begin
      pre_stop
    ensure
      begin
        stop_impl
      ensure
        post_stop
      end
    end
  end

  def wait_until_all_services_up(timeout=180)
    timeout = calc_instrumented_timeout(timeout)

    # As of yet, only storage has an explicit wait_until_all_services_up impl.
    # Use wait_until_ready for other services.
    vespa.search.each_value { |searchcluster| searchcluster.wait_until_ready(timeout) }
    vespa.storage.each_value { |stg| stg.wait_until_all_services_up(timeout) }
    vespa.qrserver.each_value { |qrs| qrs.wait_until_ready(timeout) }
    vespa.qrs.each_value { |qrs| qrs.wait_until_ready(timeout) }
    vespa.container.each_value { |container| container.wait_until_ready(timeout) }
    vespa.metricsproxies.each_value { |metrics_proxy| metrics_proxy.wait_until_ready(timeout) }
  end

  # Waits until storage services and docprocs are ready.
  def wait_until_ready(timeout=180)
    timeout = calc_instrumented_timeout(timeout)

    vespa.search.each_value { |searchcluster| searchcluster.wait_until_ready(timeout) }
    vespa.storage.each_value { |stg| stg.wait_until_ready(timeout) }
    vespa.qrserver.each_value { |qrs| qrs.wait_until_ready(timeout) }
    vespa.qrs.each_value { |qrs| qrs.wait_until_ready(timeout) }
    vespa.container.each_value { |container| container.wait_until_ready(timeout) }
    vespa.metricsproxies.each_value { |metrics_proxy| metrics_proxy.wait_until_ready(timeout) }
  end

  def getcluster(args={})
    clusters = args[:clusters] ? args[:clusters] : [ ]
    if args[:cluster]
      clusters << args[:cluster]
    end

    if clusters.empty?
      # find the one and only search cluster, or raise exception
      if vespa.search.keys.length == 1
        clusters << vespa.search.keys.first
      elsif vespa.search.keys.length > 1
        raise "Multiple search clusters are defined. Specify which one(s) to wait for a new " +
          "online index in by specifying the :cluster or :clusters arguments."
      elsif vespa.search.keys.length == 0
        raise "No search clusters are defined. Use the feed or feedfile methods instead of index " +
          "for feeding to storage only."
      end
    end
    return clusters
  end

  # Feeds the given _file_
  # Default _file_ is selfdir + feed.xml.
  def index(file=selfdir+"feed.xml", args={})
    # feed from the adminserver host
    feeder = vespa.adminserver
    feedoutput = feeder.feedfile(file, args)
    feedoutput
  end

  # Asserts that the http response code matches _responsecode_, and
  # optionally that the response contains the headers in _compareheaders_
  def assert_httpresponse(query, queryheaders = {}, responsecode = 200, compareheaders = nil, regexp = false)
    result = search(query, 0, queryheaders)
    assert_equal(responsecode, result.responsecode.to_i, 
                 "HTTP Response code #{result.responsecode} doesn't match expected value (#{responsecode}) Result returned: #{result.xmldata}")
    if compareheaders
      compareheaders.each_pair {|key, value|
          assert(result.responseheaders.has_key?(key.downcase), "Header #{key} not present in the response")
          if value
            assert_not_nil(result.responseheaders[key.downcase], "Header #{key} doesn't have any value")
            if regexp
              response_headers = result.responseheaders[key.downcase]
              # Use value as it is here, since it is always a regexp
              assert(response_headers[0] =~ value, "Header '#{key}' has value '#{response_headers[0]}', expected '#{value}'")
            else
              # TODO: Different between ruby 1.8 and 1.9, remove check when 1.8 is gone
              maybe_array = result.responseheaders[key.downcase]
              response_headers = (maybe_array.is_a?(Array) ? maybe_array : [maybe_array]).map { |elem| elem.downcase }
              # Each value for a response header is an array. For simplicity and backwards compatibility, 
              # make it a string if there is just one element
              downcased_values = Array.new
              if value.class == Array
                value.each { |elem|
                downcased_values.push(elem.to_s.downcase)
              }
              else #String
                downcased_values.push(value.to_s.downcase)
              end
              assert_equal(downcased_values, response_headers, "Header '#{key}' has value '#{response_headers}', expected '#{downcased_values}'")
            end
          end
      }
    end
  end

  def assert_httpresponse_regexp(query, queryheaders = {}, responsecode = 200, compareheaders = nil)
    assert_httpresponse(query, queryheaders, responsecode, compareheaders, true)
  end

  def assert_query_no_errors(query)
    result = search(query)
    lines = "missing result.json[root]"
    rjson = result.json if result
    rroot = rjson['root'] if rjson
    lines = rroot['errors'] if rroot
    assert(lines == nil, "Result contains errors: #{lines}")
  end

  def assert_query_errors(query, errors = [])
      assert_query_errors_with_timeout(5, query, errors)
  end

  def assert_query_errors_without_timeout(query, errors = [])
    assert_query_errors_base(search_base(query), errors)
  end

  def assert_query_errors_with_timeout(timeout, query, errors = [])
    assert_query_errors_base(search_with_timeout(timeout, query), errors)
  end

  def assert_query_errors_base(result, errors = [])
    lines = nil
    rjson = result.json if result
    rroot = rjson['root'] if rjson
    lines = rroot['errors'] if rroot
    assert(lines, "Expected errors: #{errors}, found none")

    for error in errors
      foundit = false
      m = Regexp.compile(error)
      lines.each { |line|
        if m.match(line.to_s) || line == error
          puts "Found expected query error: "
          puts line
          foundit = true
        end
      }
      assert(foundit, "Did not find expected query error: #{error}")
    end
  end

  # Custom method for checking grouping results, for now only a
  # simple diff or the result XML
  def assert_xml_result_with_timeout(timeout, query, savedresultfile, qrserver_id=0)
    timeout = calculateQueryTimeout(timeout)
    query = query + "&timeout=" + timeout.to_s
    assert_xml_result(query, savedresultfile, qrserver_id)
  end
  def assert_xml_result(query, savedresultfile, qrserver_id=0)
    result = search_base(query + '&format=xml', qrserver_id)
    assert_xml(result.xmldata, savedresultfile)
  end
  def assert_xml(xml, savedresultfile)
    tmp = Tempfile.new("tmpresult")
    tmp.puts(xml)
    tmp.flush

    # TODO: Begin remove when group rendering is finalized.
    filter =
      "grep -v \"<id>.*</id>\\|<result version=\\\"1.0\\\".*\" | " +
      "grep -v \"<sddocname>.*</sddocname>\" | " +
      "grep -v \"<field name=\\\"sddocname\\\">.*</field>\" | " +
      "grep -v \"<continuation.*continuation>\" | " +
      "sed 's/ coverage-docs=.*\">/>/g' | " +
      "sed 's/ source=.*>/>/g' "
    pipe = IO.popen("cat #{tmp.path} | " + filter)
    noid_query = Tempfile.new("noid_query")
    noid_query.puts(pipe.read)
    noid_query.close
    pipe.close

    pipe = IO.popen("cat #{savedresultfile} | " + filter)
    noid_saved = Tempfile.new("noid_saved")
    noid_saved.puts(pipe.read)
    noid_saved.close
    pipe.close

    pipe = IO.popen("diff -u #{noid_saved.path} #{noid_query.path}")
    # TODO: End remove.
    # TODO: pipe = IO.popen("diff -u #{savedresultfile} #{tmp.path}")

    output = pipe.read
    pipe.close
    assert(output.size == 0,
           "Difference in xml output:\n" +
           "#{output}" +
           "Expected: #{savedresultfile}")
  end

  # Asserts that the result from _query_ matches the content in
  # _savedresultfile_ (relative to the test dir) based on XML comparing.
  # Sorting by a spesific field is performed if _sortfield_ is set.
  # All fields except for relevancy are compared by default unless
  # _fieldstocompare_ is set (array of strings).
  def assert_result(query, savedresultfile, sortfield=nil, fieldstocompare=nil, qrserver_id=0, explanationstring="")
    assert_result_with_timeout(5, query, savedresultfile, sortfield, fieldstocompare, qrserver_id, explanationstring)
  end

  def assert_result_with_timeout(timeout, query, savedresultfile, sortfield=nil, fieldstocompare=nil, qrserver_id=0, explanationstring="")
    # save_result_with_timeout(timeout, query, savedresultfile)
    result = search_with_timeout(timeout, query, qrserver_id)
    assert_result_base(query, result, savedresultfile, sortfield, fieldstocompare, explanationstring)
  end

  def assert_result_base(query, result, savedresultfile, sortfield=nil, fieldstocompare=nil, explanationstring="")
    if explanationstring != ""
      explanationstring=explanationstring + ": "
    end
    result = Resultset.new(result.xmldata, query)
    result.setcomparablefields(fieldstocompare)
    saved_result = create_resultset(savedresultfile)
    saved_result.setcomparablefields(fieldstocompare)

    if sortfield
      result.sort_results_by(sortfield)
      saved_result.sort_results_by(sortfield)
    end

    # check that the hitcount is equal to the saved hitcount
    assert_equal(saved_result.hitcount, result.hitcount, \
                 explanationstring + "Query '#{query}' returned unexpected number of hits. Answer file: #{savedresultfile}")

    # check that the hits are equal to the saved hits
    saved_result.hit.each_index do |i|
      assert(saved_result.hit[i].check_equal(result.hit[i]), explanationstring + "At hit " + i.to_s + ". Answer file: #{savedresultfile}")
    end
    assert(Resultset.approx_cmp(saved_result.groupings, result.groupings, "groupings"),
           explanationstring + "different grouping results: expected >>>\n#{saved_result.json}\n<<< but got >>>\n#{result.json}\n<<<")
  end

  # Calls assert_result until the result matches expected result.
  def poll_compare(query, expected, sort_field=nil, fields_to_compare=nil, timeout=120, verbose=false)
    saved_result = create_resultset(expected)
    saved_result.setcomparablefields(fields_to_compare)
    saved_result.sort_results_by(sort_field) if sort_field
    equal = true
    timeout = calculateQueryTimeout(timeout)

    result = nil
    timeout.times do
      if verbose
          puts "\npoll_compare:"
      end
      result = search(query)
      result.setcomparablefields(fields_to_compare)
      result.sort_results_by(sort_field) if sort_field
      equal = false if saved_result.hitcount != result.hitcount
      saved_result.hit.each_index do |i|
        equal = false if saved_result.hit[i] != result.hit[i]
        if saved_result.hit[i] != result.hit[i]
          if verbose
            puts "At hit #{i} in poll_compare:"
            puts "expected: " + saved_result.hit[i].to_s
            puts "actual: " + result.hit[i].to_s
          end
        end
      end
      if equal
        break
      end
      equal = true
      sleep 1
      # save_result(query, expected)
    end
    assert_result_base(query, result, expected, sort_field, fields_to_compare)
  end

  # Asserts that the result from _query_ matches the content in _expectfile_
  # for a spesific _field_ based on XML comparing. This method is a convenience method
  # for assert_result. Sorting is optional.
  def assert_field(query, expectfile, field, sort=false, timeout=5)
    assert_result_with_timeout(timeout, query, expectfile, sort ? field : nil, [field])
  end

  # Asserts that the result from _query_or_result_ matches the content given
  # in a field, for a given hit number.
  def assert_field_value(query_or_result, fieldname, expectedvalue, hitnumber=0, explanationstring="")
    if explanationstring != ""
      explanationstring=explanationstring + ": "
    else
      explanationstring = "Expected hit[#{hitnumber}].#{fieldname} == '#{expectedvalue}'"
    end
    result = (query_or_result.is_a?(String) ? search(query_or_result, 0) : query_or_result)

    # check that the hits are equal to the saved hits
    assert_equal(to_utf8(expectedvalue), result.hit[hitnumber].field[fieldname].to_s, explanationstring)
  end

  # Asserts that the result from query_or_result has the expected tensor cells in the given tensor field, for a given hit number.
  def assert_tensor_field(expected_cells, query_or_result, field_name, hit=0)
    result = (query_or_result.is_a?(String) ? search(query_or_result, 0) : query_or_result)
    field_result = result.hit[hit].field[field_name]
    exp_value = TensorResult.new(expected_cells)
    act_value = TensorResult.new(field_result)
    assert_equal(exp_value, act_value)
  end

  def assert_tensor_cells(expected_cells, actual_cells, explanation="")
    sort_tensor_cells(expected_cells)
    sort_tensor_cells(actual_cells)
    assert_equal(expected_cells, actual_cells, explanation)
  end

  def sort_tensor_cells(cells)
    cells.sort! { |x,y| x['address'].to_a.sort <=> y['address'].to_a.sort }
  end

  # Asserts that the result _query_ matches the content of
  # _expected_result_file_ based on string comparing. Filtering and sorting are optional.
  #
  # The given _query_ is sent to the first qrserver and the lines in the result data are
  # filtered if _filter_exp_ (regexp) is not nil. The expected result is filtered the same
  # way. If sort (boolean) is set to true, the filtered results are sorted.
  def assert_result_matches(query, expected_result_file, filter_exp=nil, sort=false, qrserver_id=0, regexp_matching=false)
    result_xml = search(query, qrserver_id).xmldata
    expected_lines = []
    File.open(expected_result_file) do |file|
      expected_lines = file.readlines
    end

    @current_assert_file = expected_result_file
    assert_resultsets_match(result_xml.split("\n", -1), expected_lines, filter_exp, sort, regexp_matching)
    @current_assert_file = nil
  end

  def assert_result_matches_regexp(query, expected_result_file, filter_exp=nil, sort=false, qrserver_id=0)
    assert_result_matches(query, expected_result_file, filter_exp, sort, qrserver_id, true)
  end

  # Asserts that the result _query_ does not match the content of
  # _expected_result_file_ based on string comparing. Filtering and sorting are optional.
  #
  # The given _query_ is sent to the first qrserver and the lines in the result data are
  # filtered if _filter_exp_ (regexp) is not nil. The expected result is filtered the same
  # way. If sort (boolean) is set to true, the filtered results are sorted.
  def assert_not_result_matches(query, expected_result_file, filter_exp=nil, sort=nil, qrserver_id=0)
    result_xml = search(query, qrserver_id).xmldata
    expected_lines = []
    File.open(expected_result_file) do |file|
      expected_lines = file.readlines
    end
    @current_assert_file = expected_result_file
    assert_not_resultsets_match(result_xml.split("\n", -1), expected_lines, filter_exp, sort)
    @current_assert_file = nil
  end

  # Asserts that the two queries produce matching results, with optional sorting/filtering.
  def assert_queries_match(query1, query2, filter_exp=nil, sort=false, qrserver_id=0)
    result_xml1 = search(query1, qrserver_id).xmldata.split("\n")
    result_xml2 = search(query2, qrserver_id).xmldata.split("\n")
    assert_resultsets_match(result_xml1, result_xml2, filter_exp, sort)
  end

  # Asserts that the two queries produce matching results, with optional sorting/filtering.
  def assert_not_queries_match(query1, query2, filter_exp=nil, sort=false, qrserver_id=0)
    result_xml1 = search(query1, qrserver_id).xmldata
    result_xml2 = search(query2, qrserver_id).xmldata
    assert_not_resultsets_match(result_xml1.split("\n"), result_xml2.split("\n"), filter_exp, sort)
  end

  # Converts string to utf_8
  def to_utf8(str)
    if RUBY_VERSION == "1.8.7"
      str
    else
      str.force_encoding(Encoding::UTF_8.name)
    end
  end

  def to_utf8_regex(regex)
    if regex.nil?
      nil
    elsif RUBY_VERSION == "1.8.7"
      regex
    else
      Regexp.new(to_utf8(regex.to_s))
    end
  end

  def to_ascii_8bit(str)
    if RUBY_VERSION == "1.8.7"
      str
    else
      str.force_encoding(Encoding::ASCII_8BIT.name)
    end
  end

  def ignore_xml_coverage(lines)
    fixed_lines = []
    lines.each do |line|
      fixed_lines << line.gsub(/ coverage-docs=.*">/, ">")
    end
    return fixed_lines
  end

  # Asserts that the two resultsets match. Filtering and sorting is optional. Input-arguments
  # must be arrays of result-lines. If necessary, execute split("\n", -1) on the input first
  #
  # This will normally not be called directly, but is used by assert_result_matches and
  # assert_queries_match.
  def assert_resultsets_match(result_lines, expected_lines, filter_exp=nil, sort=false, regexp_matching=false)
    result_lines = ignore_xml_coverage(result_lines)
    expected_lines = ignore_xml_coverage(expected_lines)
    if filter_exp
      filter_exp = to_utf8_regex(filter_exp)
      expected_lines.delete_if {|line| !to_utf8(line).match(filter_exp) }
      result_lines.delete_if   {|line| !to_utf8(line).match(filter_exp) }
      expected_lines.collect!  {|line| line.chomp.strip}
      if sort
        result_lines.sort!
        expected_lines.sort!
      end

      assert(result_lines.length == expected_lines.length, "Expected #{expected_lines.length} lines in result, " +
             "but got #{result_lines.length} lines.\n\nExpected lines:\n#{expected_lines.join(%Q!\n!)}\n\n" +
             "Returned lines:\n#{result_lines.join(%Q!\n!)}" + (@current_assert_file != nil ? "Answer file: #{@current_assert_file}" : ""))

      expected_lines.each_index do |i|
        result = result_lines[i].strip
        if regexp_matching then
          assert(result.match(Regexp.new(expected_lines[i])), "Result line #{i}:\n#{result} does not match " +
                "expected result regexp #{i}:\n#{expected_lines[i]}" + (@current_assert_file != nil ? "Answer file: #{@current_assert_file}" : ""))
        else
          assert(result == expected_lines[i], "Result line #{i}:\n#{result} does not match " +
                "expected result line #{i}:\n#{expected_lines[i]}" + (@current_assert_file != nil ? "Answer file: #{@current_assert_file}" : ""))
        end
      end

    else
      offset = 0
      exp_xml = expected_lines.join("\n")
      got_xml = result_lines.join("\n")
      expected_lines.each do |line|
        index = got_xml.index(line, offset)
        assert(index, "Not found: '#{line}' at #{offset} matching '#{exp_xml}' and '#{got_xml}'" + (@current_assert_file != nil ? "Answer file: #{@current_assert_file}" : ""))
        offset = index + line.length - 1
      end
    end

  end

  # Asserts that the two resultsets don't match. Filtering and sorting is optional.
  #
  # This will normally not be called directly, but is used by assert_result_matches and
  # assert_queries_match.
  def assert_not_resultsets_match(result_lines, expected_lines, filter_exp=nil, sort=false)
    if filter_exp
      expected_lines.delete_if {|line| !line.match(filter_exp) }
      result_lines.delete_if {|line| !line.match(filter_exp) }
      expected_lines.collect! {|line| line.chomp}
      if sort
        result_lines.sort!
        expected_lines.sort!
      end

      if (result_lines.length != expected_lines.length)
        return
      end

      expected_lines.each_index do |i|
        if(result_lines[i] != expected_lines[i])
          return
        end
      end
    end
    assert(false, "Resultsets match, when they shouldn't" + (@current_assert_file != nil ? "Answer file: #{@current_assert_file}" : ""))
  end

  # Gets vespa config from config proxy (localost, port 19090), unless hostname and/or port is supplied
  def getvespaconfig(config_name, config_id, vespa_version=nil, hostname=nil, port=nil, debug=nil)
    cmd = "vespa-get-config -j -n #{config_name} -i #{config_id}"
    cmd += " -s #{get_configserver_hostname}" if hostname
    cmd += " -p #{port}" if port
    cmd += " -V #{vespa_version}" if vespa_version
    cmd += " -d" if debug
    (exitcode, output) = vespa.adminserver.execute(cmd, :noecho => true, :exitcode => true, :nostderr => true)
    if exitcode.to_i == 0
      output = print_and_remove_debug_output_from_getvespaconfig(output) if debug
      JSON.parse(output)
    else
      raise "Could not get config: #{output}"
    end
  end

  def linux_distribution_CentOS?
    File.open('/etc/redhat-release') { |f| f.readline }.start_with?('CentOS')
  end

  def has_active_sanitizers
    return false if @sanitizers.nil?
    return false if @sanitizers == [ 'none' ]
    true
  end

  private
  def print_and_remove_debug_output_from_getvespaconfig(output)
    puts "Debug output from getvespaconfig:"
    start_of_json = false
    new_output = ""
    output.split("\n").each do |line|
      start_of_json = true if line =~ /^{/
      if start_of_json
        new_output += line
      else
        puts line
      end
    end
    puts new_output
    new_output
  end

  def get_feed_node(params)
    params[:feed_node] ? params[:feed_node] : vespa.adminserver
  end

  def feeder_numthreads
    1
  end

  def augment_feeder_params(params_out)
    if !params_out[:numthreads]
      params_out[:numthreads] = feeder_numthreads
    end
  end

  # Calls feed on the first distributor, and uses the default docproc
  # if it is defined in the application package.
  def feed(params={})
    feeder = get_feed_node(params)
    augment_feeder_params(params)
    feeder.feed(params)
  end

  # Calls feedfile on the first distributor, and uses the default docproc
  # if it is defined in the application package.
  def feedfile(file, params={})
    feeder = get_feed_node(params)
    augment_feeder_params(params)
    feeder.feedfile(file, params)
  end

  # Feeds the buffer given as argument
  def feedbuffer(buffer, params={})
    feeder = get_feed_node(params)
    augment_feeder_params(params)
    feeder.feedbuffer(buffer, params)
  end

  # Pipe stdout of the given process command into the feeder. Run until
  # the process has terminated and the feeding is complete. No temporary
  # feed files are created or transferred.
  def feed_stream(command, params={})
    feeder = get_feed_node(params)
    augment_feeder_params(params)
    feeder.feed_stream(command, params)
  end

  # Feeds the file specified in params and waits for expected number of document.
  def feed_and_wait_for_docs(doc_type, wanted_hitcount, feed_params={}, path="", query_params={})
    query = "#{path}query=sddocname:#{doc_type}&nocache&hits=0&streaming.selection=true"
    return feed_and_wait_for_hitcount(query, wanted_hitcount, feed_params, query_params)
  end

  # Feeds the file specified in params and waits for expected number of hits for the given query.
  def feed_and_wait_for_hitcount(query, wanted_hitcount, feed_params={}, query_params={})
    timeout = feed_params[:timeout]
    timeout = 120 if timeout == nil
    feederoutput = feed(feed_params)
    wait_for_hitcount(query, wanted_hitcount, timeout, 0, query_params)
    return feederoutput
  end

  # Executes _command_ on _node_ and checks that it returns _expected_exitcode_ and
  # outputs _expected_outputs_
  def assert_exec_output(node, command, expected_exitcode, expected_outputs)
    params = {}
    params[:exceptiononfailure] = false
    params[:exitcode] = true
    (exitcode, output) = node.execute(command, params)
    assert_equal(expected_exitcode.to_s, exitcode, "Wrong exitcode returned")
    assert_correct_output(expected_outputs, output)
  end

  # Execute command on node and return list where element 0 is exitcode and
  # element 1 is merged stdout and stderr output
  def execute(node, command)
    params = {}
    params[:exceptiononfailure] = false
    params[:exitcode] = true
    (exitcode, output) = node.execute(command, params)
    return [exitcode.to_i, output]
  end

  # Feeds _feedfile_ and asserts that vespa-feeder produces _expected_outputs_.
  def assert_feed(feedfile, expected_outputs, args = {})
    args[:exceptiononfailure] = false
    feeder_output = feedfile(feedfile, args)
    assert_correct_output(expected_outputs, feeder_output)
  end

  # Indexes _feedfile_ and asserts that vespa-feeder produces _expected_outputs_
  # (output can be either an array of strings which are checked rexexp-style,
  # or a single string which is matched exactly
  def assert_index(feedfile, expected_outputs, args = {})
    args[:exceptiononfailure] = false
    feeder_output = index(feedfile, args)
    assert_correct_output(expected_outputs, feeder_output)
  end

  # Reads the tmpfile last generated by vespa-feeder and asserts that it contains _expected_outputs_.
  def assert_correct_output(expected_outputs, command_output)
    foundit = check_correct_output(expected_outputs, command_output)
    assert(foundit, "Did not find in command output: #{expected_outputs}")
  end

  # Reads the tmpfile last generated by vespa-feeder and returns true if it contains expected output.
  def check_correct_output(expected_outputs, command_output)
    puts "Command output:"
    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "#{command_output}"
    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ==== ===="

    if expected_outputs.class == Array

      @lines = command_output.split(/\n/)
      puts "Feeder produced " + @lines.length.to_s + " lines of output."

      for expected_output in expected_outputs
        foundit = false;
        m = Regexp.compile(expected_output)
        @lines.each { |line|
          if m.match(line) || line == expected_output
            puts "Found expected command output:"
            puts line
            foundit = true
          end
        }
        return foundit;
      end
      return true
    else
      return expected_outputs == command_output
    end
  end

  # Asserts that the vespa logarchive on the logserver matches _regexp_,
  # and return the number of matches
  def assert_log_matches(regexp, timeout=0, args={})
    matches = vespa.logserver.log_matches(regexp, args)
    endtime = Time.now.to_i + timeout.to_i
    while (Time.now.to_i < endtime) && (matches == 0)
      sleep 1
      matches = vespa.logserver.log_matches(regexp, args)
    end

    assert(matches > 0, "#{regexp} produced 0 matches in the vespa log")
    return matches
  end

  # Waits for that _regexp_ matches the vespa logarchive on the logserver the expected number of times.
  def wait_for_log_matches(regexp, expected_matches, timeout=120, args={})
    matches = vespa.logserver.log_matches(regexp, args)
    endtime = Time.now.to_i + timeout.to_i
    while (Time.now.to_i < endtime) && (matches < expected_matches)
      sleep 1
      matches = vespa.logserver.log_matches(regexp, args)
    end

    assert_equal(expected_matches, matches, "Expected #{regexp} to produce #{expected_matches} matches in the vespa log, but produced #{matches} matches")
    return matches
  end

  # Waits for that _regexp_ matches the vespa logarchive on the logserver at least the expected number of times.
  def wait_for_atleast_log_matches(regexp, expected_matches, timeout=120, args={})
    matches = vespa.logserver.log_matches(regexp, args)
    endtime = Time.now.to_i + timeout.to_i
    while (Time.now.to_i < endtime) && (matches < expected_matches)
      sleep 1
      matches = vespa.logserver.log_matches(regexp, args)
    end

    assert(matches >= expected_matches, "Expected #{regexp} to produce at least #{expected_matches} matches in the vespa log, but produced #{matches} matches")
    return matches
  end

  # Asserts that the vespa logarchive on the logserver does not match _regexp_
  def assert_log_not_matches(regexp, args={})
    matches = vespa.logserver.find_log_matches(regexp, args)
    assert(matches.size == 0, "#{regexp} produced #{matches.size} matches in the vespa log: #{matches}")
  end

  # Asserts that valgrind has been run with no errors reported.
  def assert_no_valgrind_errors
    return if not @valgrind

    errors = 0
    filenames = []
    valgrindlogs = Dir.glob(dirs.valgrindlogdir+"/*")
    #assert(valgrindlogs.length > 0, "No valgrind logfiles found in #{dirs.valgrindlogdir}")

    valgrindlogs.each do |filename|
      IO.foreach(filename) do |line|
        if line =~ /ERROR SUMMARY: (\S+) errors from (\S+) contexts/
          if $1.to_i > 0
            errors += 1
            filenames << filename
          end
        end
      end
    end
    assert_equal(0, errors, "Valgrind logfiles containing errors:\n#{filenames.join("\n")} (on #{Socket.gethostname})")
  end

  def assert_no_sanitizer_warnings
    return unless has_active_sanitizers
    sanitizer_logs = Dir.glob(dirs.sanitizerlogdir+"/*")
    assert_equal(0, sanitizer_logs.length, "#{sanitizer_logs.length} sanitizer log files present (on #{Socket.gethostname})")
  end

  def assert_result_hitcount(result, wanted_hitcount)
    hitcount = result.hitcount
    assert_equal(wanted_hitcount, hitcount, "Query returned unexpected number of hits.")
  end

  # Asserts that the _query_or_result_ has a total hit count equal to _wanted_hitcount_
  def assert_hitcount_withouttimeout(query, wanted_hitcount, qrserver_id=0, params = {})
    assert_result_hitcount(search_base(query, qrserver_id, {}, false, params), wanted_hitcount)
  end

  # Asserts that the _query_or_result_ has a total hit count equal to _wanted_hitcount_
  def assert_hitcount(query_or_result, wanted_hitcount, qrserver_id=0, params = {})
    if query_or_result.respond_to?(:hitcount)
      assert_result_hitcount(query_or_result, wanted_hitcount)
    else
      assert_hitcount_with_timeout(5, query_or_result, wanted_hitcount, qrserver_id, params)
    end
  end

  # Asserts that the _query_or_result_ has a total hit count equal to _wanted_hitcount_
  def assert_hitcount_with_timeout(timeout, query, wanted_hitcount, qrserver_id=0, params = {})
    timeout = calculateQueryTimeout(timeout)
    query = query + "&timeout=" + timeout.to_s
    assert_hitcount_withouttimeout(query, wanted_hitcount, qrserver_id, params)
  end

  # Waits until _query_ has at least _wanted_hitcount_ hits.
  def wait_for_atleast_hitcount(query, wanted_hitcount, timeout_in=60, qrserver_id=0)
    hitcount = search(query, qrserver_id).hitcount

    timeout = timeout_in
    timeout = calculateQueryTimeout(timeout)

    begin
      Timeout::timeout(timeout) do |timeout_length|
        while true
          begin
            hitcount = search_with_timeout(timeout_in, query, qrserver_id).hitcount
          rescue Interrupt
            puts "low-level timeout, retry"
          end
          if hitcount >= wanted_hitcount
            break
          end
          sleep 1
        end
      end
    rescue Timeout::Error
      fail("Timeout waiting for #{wanted_hitcount} hits")
    end

    return hitcount
  end

  # Waits until _query_ has a total hit count equal to _wanted_hitcount_
  def wait_for_hitcount(query, wanted_hitcount, timeout_in=60, qrserver_id=0, params={})

    hitcount = -1
    timeout = timeout_in
    timeout = calculateQueryTimeout(timeout)

    query += "&hits=0"

    puts "Waiting for #{wanted_hitcount} hits, timeout: #{timeout}"
    trynum = 0
    start = Time.now.to_i

    # check that the hitcount is equal to the wanted hitcount
    while Time.now.to_i < start + timeout
      begin
        trynum += 1
        hitcount = search_with_timeout(timeout_in, query, qrserver_id, {}, false, params).hitcount
        if wanted_hitcount == hitcount
          puts "Success on try #{trynum}: Got #{wanted_hitcount} hits"
          return true
        else
          puts "Failure on try #{trynum}: Expected #{wanted_hitcount} hits, got #{hitcount}"
        end
      rescue StandardError => e
        puts "error #{e}: #{e.backtrace}"
      rescue Interrupt
        puts "low-level timeout, retry"
      end
      sleep 1
    end
    fail("Timeout after #{trynum} tries: Expected #{wanted_hitcount} hits, got #{hitcount}")
  end

  # Waits until _query_ has a total hit not equal to _wanted_hitcount_
  def wait_for_not_hitcount(query, wanted_hitcount, timeout_in=60, qrserver_id=0)

    hitcount = -1
    timeout = timeout_in
    timeout = calculateQueryTimeout(timeout)

    query += "&hits=0"

    puts "Waiting until not #{wanted_hitcount} hits, timeout: #{timeout}"
    trynum = 0
    lasthitcount = nil
    # check that the hitcount is equal to the wanted hitcount
    begin
      Timeout::timeout(timeout) do |timeout_length|
        while true
          begin
            trynum += 1
            hitcount = search_with_timeout(timeout_in, query, qrserver_id).hitcount
            lasthitcount = hitcount
          rescue StandardError => e
            lasthitcount = "error #{e}: #{e.backtrace}"
          rescue Interrupt
            puts "low-level timeout, retry"
          end
          if wanted_hitcount != hitcount
            puts "success on try #{trynum}"
            return hitcount
          end
          sleep 1
        end
      end
    rescue Timeout::Error
      fail("Timeout after #{trynum} tries, got #{lasthitcount}")
    end
    assert_hitcount(query, lasthitcount, qrserver_id)
    return lasthitcount
  end

  # Asserts that hit no _hit_idx_ has relevancy equal to _wanted_relevancy_
  def assert_relevancy(query_or_result, wanted_relevancy, hit_idx = 0, eps = 1e-6, qrserver_id = 0)
    result = (query_or_result.is_a?(String) ? search(query_or_result, qrserver_id) : query_or_result)
    relevancy = result.hit[hit_idx].field["relevancy"].to_f
    assert_approx(wanted_relevancy, relevancy, eps, "Expected relevancy #{wanted_relevancy} for hit #{hit_idx} but was #{relevancy}")
  end

  # Waits until hit no _hit_idx_ has relevancy equal to _wanted_relevancy_
  def wait_for_relevancy(query, wanted_relevancy, hit_idx = 0, timeout = 30, eps = 1e-6, qrserver_id = 0)
    timeout = calculateQueryTimeout(timeout)
    relevancy = 0
    timeout.times do |x|
      begin
        result = search(query, qrserver_id)
	if result.hit[hit_idx] and result.hit[hit_idx].field['relevancy']
          relevancy = result.hit[hit_idx].field["relevancy"].to_f
	else
	  relevancy = 0
	end
      rescue Interrupt
        puts "low-level timeout, retry #{x}"
      end
      if check_approx(wanted_relevancy, relevancy, eps)
        break
      end
      sleep 1
    end
    assert_approx(wanted_relevancy, relevancy, eps, "Expected relevancy #{wanted_relevancy} for hit #{hit_idx} but was #{relevancy}")
  end

  # Checks that the given hash with actual features names and scores contains
  # the given hash with expected feature names and scores.
  # Uses the given epsilon when comparing scores.
  def assert_features(expected, actual, eps = 1e-6)
    expected.each do |name, score|
      puts "assert_features: #{name}:#{score}"
      assert(actual.has_key?(name), "Actual hash does not contain feature '#{name}'")
      x = score.to_f
      y = actual.fetch(name).to_f
      assert_approx(x, y, eps,"Feature '#{name}' does not have expected score. Expected: #{x} ~ #{eps}. Actual: #{y}")
    end
  end

  # Checks that the expected and actual numbers are approximately equal using the given epsilon.
  def check_approx(exp, act, eps = 1e-6)
    return ((exp >= (act - eps)) and (exp <= (act + eps)))
  end

  # Asserts that the expected and actual numbers are approximately equal using the given epsilon.
  def assert_approx(exp, act, eps = 1e-6, msg = nil)
    assert(check_approx(exp, act, eps), msg)
  end

  # Asserts that the content of reference file and the result content is exactly same
  def assert_file_content_equal(refFile,resContent, explanationstring="")
    if explanationstring.empty?
      explanationstring=explanationstring + ": "
    end

    refContArr = File.open(refFile,"r").read.split(/\n/)
    resContArr = resContent.split(/\n/)
    assert_equal(refContArr.size,resContArr.size,explanationstring + "Line count assertions : answer file: #{refFile}: ")
    for count in 0...refContArr.size
      assert_equal(refContArr[count],resContArr[count],explanationstring + "At line :" + count.to_s + ": answer file: #{refFile}: ")
    end
  end

  # Asserts that the content of reference file and the result content is matched with pattern
  def assert_file_content_match(refFile,resContent, explanationstring="")
    if explanationstring.empty?
      explanationstring=explanationstring + ": "
    end

    refContArr = File.open(refFile,"r").read.split(/\n/)
    resContArr = resContent.split(/\n/)
    assert_equal(refContArr.size,resContArr.size,explanationstring + "Line count assertions : asnswer file: #{refFile}: ")
    for count in 0...refContArr.size
      re = refContArr[count]
      assert_match(/#{re}/,resContArr[count],explanationstring + "At line :" + count.to_s + ": answer file: #{refFile}")
    end
  end

  # Read, Eval, Print Loop.
  # Should be called the following way: repl binding
  def repl(binding_res = nil)
    puts "Enter ruby statements, finish with ;"
    run = true
    while( run )
      begin
        str = input_stmt()
        if str
          puts( eval(str, binding_res).inspect )
        else
          run = false
        end
      rescue Exception => err
        puts err.inspect
      end
    end
  end

  private

  # Reads statements until matches ; at the end.
  def input_stmt()
    str = STDIN.gets("\n")
    if str
      while(  str.strip() != "" and
              str.rstrip()[-1,1] != ";" )
        str += STDIN.gets("\n")
      end

      res = str.strip()
      if res == "" or res == ";"
        res = nil
      end

      return res
    else # nothing read(e.g the user only pressed control d)
      return nil
    end

  end

  def wait_for_reconfig(expected_generation, retries=600, echo=false)
    while retries > 0
      r = vespa_config_status(echo)
      exitcode = r[0].to_i
      output = r[1]
      if exitcode == 0
        if output =~ /has the latest generation #{expected_generation}/
          break
        end
      end
      retries -= 1
      sleep 0.1
    end
    assert_equal(0, exitcode, "Services never reconfigured to latest application package, output from vespa-config-status: #{output}")
  end

  def vespa_config_status(echo=false)
    @vespa.adminserver.execute("vespa-config-status -v",
                               :exitcode => true,
                               :noecho => !echo)
  end

  def wait_for_config_generation_proxy(generation=1, config_name="document.config.documentmanager", config_id="client")
    wait_for_config_generation(generation, config_name, config_id, vespa.adminserver, 19090)
  end

  def wait_for_config_generation(generation=1, config_name="document.config.documentmanager", config_id="client", configserver=vespa.configservers["0"], port=19070)
    code = 1
    iteration = 0
    until (code == 0 || iteration > 150) do
      (exitcode, output) = vespa.adminserver.execute("vespa-get-config -d -n #{config_name} -i #{config_id} -s #{configserver.name} | grep generation | grep #{generation}", :exitcode => true)
      code = exitcode.to_i
      sleep 1
      iteration = iteration + 1
      puts "iteration #{iteration}"
    end
    assert(iteration<=150, "Timed out waiting for config generation #{generation} on #{configserver.name}")
  end

  def delete_application(hostname=nil, tenant=nil, app=nil)
    tname = @tenant_name
    app_name = @application_name
    if tenant
      tname = tenant
    end
    if app
      app_name = app
    end
    if !@configserverhostlist.empty?
      delete_application_from_server(@configserverhostlist, tname, app_name)
    end
    if hostname
      delete_application_from_server([hostname], tname, app_name)
    end
  end

  def delete_application_from_server(configserver_hosts, tenant, app)
    hostname = configserver_hosts[0]

    puts("Deleting application from config server (hostname #{hostname}, app #{app})")
    status_code = 0
    iteration = 0
    until (status_code == 200 || iteration > 5) do
      puts "Deleting application, iteration #{iteration}"
      result = delete_tenant_application(tenant, app, hostname)
      status_code = result.code.to_i
      break if status_code == 404
      sleep 1 if status_code != 200
      iteration = iteration + 1
    end

    if status_code == 404
      puts "Unable to delete application #{app}, application does not exist"
    elsif status_code != 200
      raise "Unable to delete application #{app}, got status code #{result.code}"
    end
  end

  def get_configserver_hostname
    if (@use_shared_configservers)
      hostname = @configserverhostlist.first
    else
      hostname = vespa.configservers["0"].name
    end
  end

  # Temporarily overrides setting, will be set back at end of test
  def override_environment_setting(node, name, value)
    node.override_environment_setting(name, value)
    @dirty_environment_settings = true
  end

  def get_services
    services = Array.new
    out = vespa.adminserver.execute("vespa-model-inspect services 2>/dev/null")
    out.split("\n").each do |service|
      services << service
    end
    services
  end

end

