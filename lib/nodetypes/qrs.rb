# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
    wait_until_qrservers_ready(timeout)
  end

  def wait_until_qrservers_ready(timeout)
    @qrserver.each do |k, v|
      v.wait_until_ready(timeout)
    end
  end

  def add_service(remote_serviceobject)
    if not remote_serviceobject
      return
    end
    if remote_serviceobject.servicetype == "qrserver"
      @qrserver[remote_serviceobject.index] = remote_serviceobject
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


