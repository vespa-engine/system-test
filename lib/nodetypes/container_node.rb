# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

class ContainerNode < VespaNode
  attr_accessor :http_port
  attr_accessor :connectionPool
  MAX_RETRIES = 120

  def initialize(*args)
    super(*args)
    @refs = []
    @http_port = @ports_by_tag["query"] if @ports_by_tag
    @connectionPool = HttpConnectionPool.new(tls_env)
  end

  def local_ip
    `/sbin/ifconfig eth0` =~ /inet addr\:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s/
    $1
  end

  def wait_until_ready(timeout = 60)
    @testcase.output("Wait until container (#{self.config_id}) ready on #{self.hostname} at port " + @http_port.to_s + " ...")
    endtime = Time.now.to_i + timeout.to_i
    begin
      status = http_get("localhost", @http_port, "/")
      return status
    rescue StandardError => e
      sleep 0.1
      retry if Time.now.to_i < endtime
      dumpJStack
      raise "Timeout while waiting for container to become ready: #{e}"
    end
  end

  def http_get2(path, header = {})
    host = local_ip
    if (host == nil)
      host = "localhost"
    end
    return http_get(host, 0, path, nil, header)
  end

  def http_get_retry(host, port, uri)
    retries_left = MAX_RETRIES
    begin
      http_get(host, port, uri)
    rescue SystemCallError
      if retries_left > 0
        retries_left -= 1
        sleep 1
        retry
      end
    end
  end

  def http_get(host, port, query, post = nil, header = {})
    query = query.tr(" ", "+")
    if port == 0
      port = @http_port
    end

    http = @connectionPool.acquire(host, port)
    http.getConnection.read_timeout = 7200
    result = (post != nil) ? http.getConnection.post(query, post, header) : http.getConnection.get(query, header)
    @connectionPool.release(http)
    return result
  end

  def search(query, port=0, header = {}, verbose=false, params = {})
    if port == 0
      port = @http_port
    end

    @testcase.output("Querying port #{port} with query: #{query}") if verbose

    @retries = MAX_RETRIES
    resultset = nil
    begin
      retries = 0
      while true do
        response, data = http_get(params[:use_local_ip] ? local_ip : "localhost", port, query, nil, header)
        data = response.body
        resultset = Resultset.new(data, query, response)
        @refs.push(resultset)

        errorretries = params[:errorretries] || 0

        # Output any errors from test result
        if not data.scan(/errordetails/).empty?
          if retries >= errorretries
            @testcase.output("Query returned error: #{data}")
            @testcase.log_query_and_result(query, data)
            return resultset
          end
        else
          @testcase.log_query_and_result(query, data)
          return resultset
        end

        sleep 1
        retries += 1
        @testcase.output("Retrying after query with errors: #{retries}")
      end
    rescue SystemCallError
      if @retries == MAX_RETRIES and verbose
        @testcase.output("\nError connecting to qrserver on port #{port}:\n #{$!}\nRetrying.", false)
      end
      @testcase.output(".", false)
      sleep 1
      if @retries > 0
        @retries = @retries - 1
        retry
      else
        raise
      end
    end
    resultset
  end

  def post_search(query, postdata, port=0, header = {}, verbose = true)
    if port == 0
      port = @http_port
    end

    @retries = MAX_RETRIES
    resultset = nil
    begin
      response, data = http_get("localhost", port, query, postdata, header)
      data = response.body

      resultset = Resultset.new(data, query, response)
      @refs.push(resultset)
      # Output any errors from test result
      if not data.scan(/errordetails/).empty?
        if verbose
            @testcase.output("Query returned error: #{data}")
        end
      end
      return resultset
    rescue SystemCallError
      if @retries == MAX_RETRIES and verbose
        @testcase.output("\nError connecting to qrserver on port #{port}:\n #{$!}\nRetrying.", false)
      end
      @testcase.output(".", false)
      sleep 1
      if @retries > 0
        @retries = @retries - 1
        retry
      else
        raise
      end
    end
    resultset
  end

  # Returns the application version from this qrserver's ApplicationStatus handler.
  # NOTE: Requires that the container_node is already up!
  def get_application_version()
    res = search("/ApplicationStatus")
    root = JSON.parse(res.xmldata)

    if ! root.has_key? 'application'
      return nil
    end
    application = root["application"]
    if ! application.has_key? 'user'
      return nil
    end
    user = application["user"]
    if ! user.has_key? 'version'
      return nil
    end
    return user["version"]
  end

  # Returns the latest query access log file
  def get_query_access_log
    lines=`find #{Environment.instance.vespa_home}/logs/vespa/qrs -name 'QueryAccessLog*'| xargs -n 1 cat`
    return lines
  end

  def just_do_query(query, port=0)
    http_get("localhost", port, query)
  end

  ################ documentapi / gateway ##################


  def http_feed(params={})
    feedfile = create_tmpfeed(params)
    res = feedlocalfile(feedfile, params)
    res.body
  end

  def http_docapi_get(params)
    http = http = @connectionPool.acquire("localhost", @http_port)
    key_value_pairs = parse_params(params)
    if params[:remove]
      request_uri = "/remove/"
    elsif params[:removelocation]
      request_uri = "/removelocation/"
    elsif params[:visit]
      request_uri = "/visit/"
    elsif @compatibility
      request_uri = "/document/"
    else
      request_uri = "/get/"
    end
    if not key_value_pairs.empty?
      request_uri += "?" + key_value_pairs
    end
    @testcase.output request_uri
    response, data = http.getConnection.get(request_uri)
    @connectionPool.release(http)

    # check if XML validation should be performed
    if not params[:novalidate]
      check_response(response)
    end
    response
  end

  def get_document(documentid, params={})
    begin
      xml = http_docapi_get(params.merge({:id => documentid})).body
      gw = GatewayXMLParser.new(xml)
      # if documentid was an array, return all docs
      if documentid.kind_of? Array
        return gw.documents
      else
        return gw.documents[0]
      end
    rescue RuntimeError => exc
      if (exc.to_s.index("not found") != nil)
        @testcase.output "Output gotten in get"
        @testcase.output exc.to_s
        return nil
      else
        raise exc
      end
    end
  end

  def parse_params(params={})
    key_value_pairs = []
    url_arguments = [:field, :type, :documenttype, :route, :contenttype,
                     :abortondocumenterror, :maxpendingdocs, :maxpendingbytes,
                     :timeout, :contentencoding, :priority, :user, :group, :asynchronous,
                     :selection, :loadtype, :fieldset, "visit.continuation", "visit.maxpendingvisitors"]
    # Treat id separately, as it may be an array
    if params.has_key? :id
      if params[:id].kind_of? Array
        i = 0
        params[:id].each do |d|
          key_value_pairs << "id[#{i}]=#{CGI.escape(d)}"
          i += 1
        end
      else
        key_value_pairs << "id=#{CGI.escape(params[:id])}"
      end
    end
    url_arguments.each do |argument|
      if params.has_key? argument
        key_value_pairs << "#{argument}=#{CGI.escape(params[argument].to_s)}"
      end
    end
    key_value_pairs.join("&")
  end

  def check_response(response)
    if (response.code != "200")
      raise "HTTP gateway returned error code "+response.code+": "+response.message
    end
  end

  def stop
    ret = super
    dumpJStack unless ret
    return ret
  end

  def http_post(buf, params={})
    key_value_pairs = parse_params(params)
    http = @connectionPool.acquire("localhost", @http_port)
    http.getConnection.read_timeout=190

    if (params[:contenttype])
      contenttype = params[:contenttype]
    else
      contenttype = "application/xml"
    end

    if (@compatibility)
      command = "document"
    elsif params[:multiget]
      command = "get"
    elsif params[:multiremove]
      command = "remove"
    elsif params[:field]
      command = "binaryfeed"
    else
      command = "feed"
    end

    key_value_pairs = parse_params(params)
    if key_value_pairs.empty?
      request_uri = "/" + command + "/"
    else
      request_uri = "/" + command + "/?" + key_value_pairs
    end
    httpheaders={"Content-Type" => contenttype}
    if (params[:contentencoding])
      httpheaders["Content-Encoding"] = params[:contentencoding]
    end
    response, data = http.getConnection.post(request_uri, buf, httpheaders)
    @connectionPool.release(http)

    check_response(response)
    response
  end

  private
  def feedlocalfile(filename, params={})
    response = nil
    File.open(filename) do |fp|
      buf = fp.read
      response = http_post(buf, params)
    end
    File.delete(filename)
    response
  end

end
