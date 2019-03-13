# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class SDFile

  attr_reader :file_name, :global

  def initialize(file_name, global)
    @file_name = file_name
    @global = global
  end

end
