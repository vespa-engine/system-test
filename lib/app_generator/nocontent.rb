# Copyright Vespa.ai. All rights reserved.
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
