# Copyright Vespa.ai. All rights reserved.
class SDFile

  attr_reader :file_name, :global, :selection, :mode

  def initialize(file_name, global, selection = nil, mode = nil)
    @file_name = file_name
    @global = global
    @selection = selection
    @mode = mode
  end

end
