# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/app'

class NoContent < Content
  def to_xml(indent)
    return ""
  end

  def sd_files
    nil
  end

  def all_sd_files
    []
  end
end
