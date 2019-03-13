# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class NodeGraph
  include NodeStats

  def initialize(noderrd, testcase)
    @noderrd = noderrd
    @testcase = testcase
    @nodename = @noderrd.nodename
    @rrd_name = @noderrd.rrd_name
  end

  def create_graphs
    types = find_stat_types
    cfs = ["AVERAGE", "MAX"]
    types.each do |type|
      cfs.each do |cf|
        draw_graph(cf, type)
      end
    end
  end

  def find_stat_types
    types = []
    getstats.each do |stat|
      types.push(stat["type"])
    end
    types.uniq!
  end

  def draw_graph(cf, type="custom", stats=[])
    if stats.length == 0
      getstats.each do |stat|
        stats.push(stat) if stat["type"] == type
      end
    end

    pngfile = @testcase.dirs.graphdir + @nodename + "_" + type + "_" + cf.downcase + ".png"
    width = 400
    height = 100
    start_time = @noderrd.start_time
    end_time = Time.now.to_i
    if (end_time - start_time < width)
      start_time = end_time - width
    end
    unit = stats[0]["unit"]  # use unit from first statistic
    cmd =  "rrdtool graph #{pngfile} "
    cmd += "--width #{width} --height #{height} "
    cmd += "--start #{start_time} --end #{end_time} "
    cmd += "--vertical-label #{unit} "

    colours = getcolours
    stats.each do |stat|
      colour = colours.shift
      cmd += "DEF:my_#{stat['name']}=#{@rrd_name}:#{stat['name']}:#{cf} "
      cmd += "LINE1:my_#{stat['name']}##{colour}:#{stat['name']} "
    end
    cmd += "2>&1"

    result = `#{cmd}`
  end

end

