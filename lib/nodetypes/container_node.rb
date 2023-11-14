# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'
require 'openssl'

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
    return http_get(self.hostname, 0, path, nil, header)
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
        response, data = http_get("localhost", port, query, nil, header)
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
    rescue SystemCallError,OpenSSL::SSL::SSLError
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
    lines=`find #{Environment.instance.vespa_home}/logs/vespa/access -name 'QueryAccessLog*'| xargs -n 1 cat`.
      encode("UTF-8", invalid: :replace)
    return lines
  end

  def get_connection_log
    lines=`find #{Environment.instance.vespa_home}/logs/vespa/access -name 'ConnectionLog.default*'| xargs -n 1 cat`.
      encode("UTF-8", invalid: :replace)
    return lines
  end


  def to_uri(sub_path:, parameters:)
    "/document/v1/#{sub_path}?#{parameters.map { |k, v| "#{ERB::Util.url_encode(k.to_s)}=#{ERB::Util.url_encode(v)}" } .join("&")}"
  end

  def count_visit(doom, endpoint, args, visit_seconds, stderr_file, parameters, sub_path, method, body)
    documents = 0
    while Time.now.to_f < doom
      timeout = doom - Time.now.to_f
      timeout = timeout <= 1 ? 1 : timeout >= visit_seconds ? visit_seconds : timeout
      parameters[:timeout] = timeout
      uri = to_uri(sub_path: sub_path, parameters: parameters)
      command="curl -m #{2 * visit_seconds} -X #{method} #{args} '#{endpoint}#{uri}' -d '#{body}'" +
              " 2>#{stderr_file} | jq '{ continuation, documentCount, message }'"
      json = JSON.parse(execute(command))
      raise json['message'] if json['message']
      if json['documentCount']
        documents += json['documentCount']
      else
        raise "No documentCount in response; stderr: '#{readfile(stderr_file)}'"
      end
      if json['continuation']
        parameters[:continuation] = json['continuation']
      else
        parameters.delete(:continuation)
        break
      end
    end
    documents
  end

  def count_visit_until(endpoint, args, visit_seconds, stderr_file, selections, parameters, sub_path, method, body)
    documents = 0
    doom = Time.now.to_f + visit_seconds - 1
    selections.each do |selection|
      parameters[:selection] = selection
      documents += count_visit(doom, endpoint, args, visit_seconds, stderr_file, parameters, sub_path, method, body)
    end
    documents
  end

  def just_do_query(query, port=0)
    http_get("localhost", port, query)
  end

  def stop
    ret = super
    dumpJStack unless ret
    return ret
  end

  def cleanup
    @testcase.output("Cleaning qrsdocs...")
    execute("rm -rf #{Environment.instance.vespa_home}/share/qrsdocs")
    @testcase.output("Cleaning spooler dirs...")
    execute("rm -rf #{Environment.instance.vespa_home}/var/spool/vespa/events/")
  end

end
