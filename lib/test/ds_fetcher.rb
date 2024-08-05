# Copyright Vespa.ai. All rights reserved.
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
