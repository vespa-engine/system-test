# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class NodeRRD
  include NodeStats

  attr_reader :nodename, :rrd_name, :start_time

  def initialize(nodename, testcase)
    @nodename = nodename
    @testcase = testcase
    @rrd_name = @testcase.dirs.rrdsdir + @nodename + '.rrd'
    @start_time = Time.now.to_i
    create_rrd
  end

  def create_rrd
    step = 10
    heartbeat = 20

    cmd =  "rrdtool create #{@rrd_name} "
    cmd += "--start #{@start_time} --step #{step} "
    getstats.each do |stat|  # get stat list from NodeStats module
      cmd += "DS:#{stat['name']}:GAUGE:#{heartbeat}:U:U "
    end
    cmd += "RRA:AVERAGE:0.5:1:360 " # 1 hour, 10s resolution
    cmd += "RRA:AVERAGE:0.5:6:720 " # 12 hours, 1 minute resolution
    cmd += "RRA:MAX:0.5:6:720 "     # 12 hours, 1 minute resolution
    cmd += "RRA:AVERAGE:0.5:90:480 " # 5 days, 15 minute resolution
    cmd += "RRA:MAX:0.5:90:480 "     # 5 days, 15 minute resolution
    cmd += "RRA:AVERAGE:0.5:2160:360 " # 90 days, 6 hour resolution
    cmd += "RRA:MAX:0.5:2160:360 "     # 90 days, 6 hour resolution
    cmd += "2>&1"

    output = `#{cmd}`
  end

  def update_rrd(node)
    timestamp = Time.new.to_i
    cmd =  "rrdtool update #{@rrd_name} "
    cmd += "#{timestamp}:"

    getstats.each do |stat| # get stat list from NodeStats module
      statvalue = node[stat["name"]]
      cmd += "#{statvalue}:"
    end

    cmd.chop! # remove last surplus :
    cmd += " 2>&1"
    output = `#{cmd}`
  end

end

