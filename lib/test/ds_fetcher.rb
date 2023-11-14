# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance/resultmodel'


class DSFetcher
  def initialize(files)
    @files = files
  end

  def fetch
    @files.collect do |f|
      Perf::Result.read f
    end
  end
end
