# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/app'
require 'app_generator/nocontent'

class ContainerApp < App

  def initialize(has_content = true)
    super()
    if has_content then
      @content.search_type(:indexed)
      @content.provider(:none)
    else
      @content = NoContent.new
    end
    @transition_time = 0
  end

  def elastic_search
    @content.search_type(:indexed)
    self
  end

end
