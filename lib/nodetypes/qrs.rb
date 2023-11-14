# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Qrs

  attr_accessor :qrserver

  def initialize(testcase, vespa)
    @testcase = testcase
    @vespa = vespa
    @qrserver = {}
  end

  def empty?
    @qrserver.empty?
  end

  def wait_until_ready(timeout=90)
    @qrserver.each do |k, v|
      v.wait_until_ready(timeout)
    end
  end

  def add_service(remote_serviceobject)
    if not remote_serviceobject
      return
    end
    svc = remote_serviceobject.servicetype
    if svc == 'qrserver' || svc == 'container'
      @qrserver[remote_serviceobject.index] = remote_serviceobject
    else
      raise "Unknown service type '#{svc}'"
    end
  end

  def to_s
    repr_string = ""
    qrserver.each_value do |n|
      repr_string += n.to_s + "\n"
    end
    return repr_string.chomp
  end

end


