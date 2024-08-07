# Copyright Vespa.ai. All rights reserved.
# This module contains methods for fetching system level metrics that cannot be
# fetched via the metrics proxy.

module Metrics

  def memusage_rss(pid)
    memusage = 0
    IO.popen("cat /proc/#{pid}/smaps") do |f|
      f.each_line do |line|
        res = /^Rss:\s+(\d+)\skB$/.match(line)
        if res
          memusage += (res[1].to_i * 1000)
        end
      end
    end
    memusage
  end
end
