# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class DocprocNode < ContainerNode

  def initialize(*args)
    super(*args)
  end

  def wait_until_http_up(timeout = 60)
    @testcase.output("Wait until docproc HTTP handler ready at port " + @http_port.to_s + " ...")
    endtime = Time.now.to_i + timeout.to_i
    while Time.now.to_i < endtime
      begin
        https_get(@name, @http_port, '/')
      rescue StandardError => e
        sleep 0.1
        if Time.now.to_i < endtime
          retry
        else
          raise e
        end
      end
      return true
    end
    raise "Timeout while waiting for docproc HTTP handler to become ready."
  end


end
