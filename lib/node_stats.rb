# Copyright Vespa.ai. All rights reserved.

module NodeStats

  def getstats
    list = []
    list.push({"name" => "rtc_mem", "unit" => "bytes", "type" => "memory"})
    list.push({"name" => "distributor_mem", "unit" => "bytes", "type" => "memory"})
    list.push({"name" => "qrs_mem", "unit" => "bytes", "type" => "memory"})
    list.push({"name" => "rtc_cpu", "unit" => "%", "type" => "cpu"})
    list.push({"name" => "distributor_cpu", "unit" => "%", "type" => "cpu"})
    list.push({"name" => "qrs_cpu", "unit" => "%", "type" => "cpu"})
    list.push({"name" => "idle_cpu", "unit" => "%", "type" => "cpu"})
    list.push({"name" => "collisions", "unit" => "collisions", "type" => "network_collisions"})
    list.push({"name" => "bytes_out", "unit" => "bytes", "type" => "network_io"})
    list.push({"name" => "bytes_in", "unit" => "bytes", "type" => "network_io"})
    list.push({"name" => "io_transactions", "unit" => "transactions", "type" => "disk_trans"})
    list.push({"name" => "io_transfer", "unit" => "bytes", "type" => "disk_io"})
    list.push({"name" => "system_calls", "unit" => "calls/second", "type" => "system_calls"})
    list.push({"name" => "context_switches", "unit" => "switches/second", "type" => "context_switches"})
    list.push({"name" => "user_time", "unit" => "%", "type" => "cpu"})
    list.push({"name" => "system_time", "unit" => "%", "type" => "cpu"})
    list.push({"name" => "95_percentile", "unit" => "ms", "type" => "latency"})
    list.push({"name" => "99_percentile", "unit" => "ms", "type" => "latency"})
    list.push({"name" => "qps", "unit" => "queries/second", "type" => "queries"})
    return list
  end

  def getcolours
    list = ["0099FF", "669966", "CC6666", "CC33FF", "996699", "6600FF"]
  end

end

