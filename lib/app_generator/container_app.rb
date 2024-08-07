# Copyright Vespa.ai. All rights reserved.
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

end
