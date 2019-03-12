# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Docproc

  attr_accessor :docprocservice

  def initialize(testcase, vespa)
    @testcase = testcase
    @vespa = vespa
    @docprocservice = {}
  end

  def add_service(remote_serviceobject)
    if not remote_serviceobject
      return
    end
    if remote_serviceobject.servicetype == "docprocservice"
      @docprocservice[remote_serviceobject.index] = remote_serviceobject
    end
  end

  def to_s
    repr_string = ""
    docprocservice.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    return repr_string.chomp
  end

  def wait_until_ready(timeout=90)
    if docprocservice.size < 1
      return
    end

    docprocservice.each_value do |dp|
      dp.wait_until_http_up
    end

    cl = docprocservice["0"].cluster
    @testcase.output(@docprocservice["0"].config_id)
    if @docprocservice["0"].config_id =~ /^#{cl}\/\w+\.\d+/
      rpc_pattern = @docprocservice["0"].config_id + "/chain.*"
      regex_match = Regexp.new("^(" + @docprocservice["0"].config_id + "\/chain\..+)")
    else
      regex_match = Regexp.new("(docproc/cluster\.#{cl}/.+/)")
      rpc_pattern = "docproc/cluster.#{cl}/*/chain.*"
    end

    @testcase.output(rpc_pattern)
    
    @testcase.output("Waiting for #{@docprocservice.size} docprocs in cluster '#{cl}'...")
    endtime = Time.now.to_i + timeout.to_i
    while Time.now.to_i < endtime
      names, specs = @vespa.slobrok["0"].lookup_rpc_server(rpc_pattern)

      if names != nil
        # count number of docproc services, ignoring the number of chains per docproc
        docproc_service_names = {}
        names.each do |name|
          if name =~ regex_match
            docproc_service_names[$1] = true
          end
        end
        if docproc_service_names.size >= @docprocservice.size
          @testcase.output("#{docproc_service_names.size} docprocs ready.")
          return true
        end
      end
      sleep 0.1
    end
    raise "Timeout while waiting for docproc to become ready."
  end

end
