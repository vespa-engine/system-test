# Copyright Vespa.ai. All rights reserved.

module BacktraceFilter

  def filter_backtrace(backtrace)
    return ["No backtrace"] unless(backtrace)
    backtrace_removed_last_line = backtrace[0..-2]
    ignore_filter = /unit.rb|autorunner.rb|testcase.rb|assertions.rb|timeout.rb/
    backtrace_removed_last_line.delete_if { |line| line =~ ignore_filter }
    backtrace_removed_last_line
  end
end
