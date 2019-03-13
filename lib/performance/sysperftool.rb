# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance/stat'

puts "Starting performance capture period at #{Time.now}."
puts "CTRL-C to print stats for current and total period, resetting current period. CTRL-C again within 1 sec to stop."

total_period = Perf::Stat::create
last_period = total_period
last_int = Time.now

def columnify(cols)
  min_widths = []
  lines = []
  height = 0

  cols.each do |col|
    min_width = 0
    n = 1
    col_lines = col.split("\n")
    lines << col_lines
    col_lines.each do |line|
      min_width = [min_width, line.size].max
      n += 1
      height = [height, n].max
    end
    min_widths << min_width
  end

  ret = ''
  height.times do |i|
    cols.size.times do |c|
      entry = lines[c][i] || ''
      ret << entry << ' ' * (min_widths[c] - entry.size) << '|'
    end
    ret << "\n"
  end

  ret
end

Signal.trap('INT') {
  puts
  now = Time.now
  if now - last_int <= 1
    exit 0
  else
    last = "Last period:\n--------------------\n" + last_period.printable_result
    total = "Total period:\n--------------------\n" + total_period.printable_result

    last_period = Perf::Stat::create
    puts columnify([last, total])
  end
  last_int = now
  puts
}

while true
  sleep 1
end

