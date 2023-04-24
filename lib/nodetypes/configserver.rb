# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Configserver < VespaNode

  def initialize(*args)
    super(*args)
  end

  def get_config(name, configid)
    return get_json_over_http("/config/v1/#{name}/#{configid}", 19071)
  end

  def get_logfile(filename)
    content = ""
    if File.exist?(filename)
      content = File.open(filename).read
    end

    size = content.length
    chunk = 2*1024*1024
    pos = 0
    while pos*chunk < size
      yield(content[pos*chunk, (pos+1)*chunk])
      pos += 1
    end
  end
end
