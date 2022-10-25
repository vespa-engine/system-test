# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

class Qrserver < ContainerNode

  attr_reader :statusport

  def initialize(*args)
    super(*args)
    @statusport = @ports_by_tag["status"]
  end

  def wait_until_ready(timeout = 60)
    endtime = Time.now.to_i + timeout.to_i
    while Time.now.to_i < endtime
       begin
         status = super(endtime - Time.now.to_i)
       rescue StandardError => e
         sleep 0.1
         if Time.now.to_i < endtime
           retry
         else
           raise e
         end
       end
       if (status and status.body =~ /./)
         @testcase.output("Qrserver ready.")
         return true
       end
       sleep 0.1
    end
  end

  def wait_for_index(timeout = 60, cluster = nil)
    endtime = Time.now.to_i + timeout.to_i
    query = "?/query=foobar&hits=0"
    if cluster
      query += "&search=#{cluster}"
    end
    while Time.now.to_i < endtime
      begin
        result = just_do_query(query)
      rescue StandardError => e
        sleep 0.1
        if Time.now.to_i < endtime
          retry
        else
          raise e
        end
      end
      if result !~ /All searchnodes are down/
        @testcase.output("Qrserver ready.")
        return true
      end
      sleep 0.1
    end
    raise "Timeout while waiting for qrserver to become ready."
  end

  def gw_http_get(params)
    http = @connectionPool.aquire("localhost", http_port)
    key_value_pairs = parse_params(params)
    if params[:remove]
      request_uri = "/remove"
    elsif params[:removelocation]
      request_uri = "/removelocation"
    elsif params[:visit]
      request_uri = "/visit"
    elsif @compatibility
      request_uri = "/document"
    else
      request_uri = "/get"
    end
    if not key_value_pairs.empty?
      request_uri += "?" + key_value_pairs
    end
    @testcase.output request_uri
    response = http.getConnection.get(request_uri)
    @connectionPool.release(http)
    # check if XML validation should be performed
    if not params[:novalidate]
      check_response(response)
    end
    response
  end

  def get(documentid, params={})
    begin
      xml = gw_http_get(params.merge({:id => documentid})).body
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

end
