# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'

class QueryProfileCompilationTest < PerformanceTest

  def setup
    set_owner("hmusum")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start
  end

  def test_documentapi_java
    tmp = "#{dirs.tmpdir}/#{File.basename(selfdir)}"
    vespa.adminserver.copy("#{selfdir}/project", tmp)
    install_maven_parent_pom(vespa.adminserver)
    output = vespa.adminserver.execute("cd #{tmp}; #{maven_command} -Dtest.hide=false test")
    puts output
    match = output.match(/(?:Compilation time in seconds: )([0-9.]+)/)
    raise "No compilation time found in output" unless match
    time_seconds = match[1]
    raise "No compilation time found in output" unless time_seconds
    write_report([ metric_filler('compile_time_seconds', time_seconds.to_f) ])
  end

  def teardown
    stop
  end

end
