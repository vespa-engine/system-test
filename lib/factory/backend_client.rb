# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'zlib'
require 'pathname'
require 'factory_client'

class SimpleSystestSorter

  def initialize(durations, tests)
    @test_classes = tests
    @test_scores = Hash[calculate_scores(durations, tests)]
  end

  def sort
    @test_classes.to_a.sort! do |a, b|
      @test_scores[b[0]] <=> @test_scores[a[0]]
    end
  end

  private

  def calculate_scores(durations, test_objects)
    test_objects.map do |test_object, method_name|
      score = durations["#{test_object.class.to_s}::#{method_name}"].to_f
      score = 100 if score < 0.1 # Use 100 as fallback when new test, unknown duration due to previous run aborted etc.
      score = score + test_object.num_hosts * 2000 if test_object.num_hosts > 1
      score = score + 1e10 if test_object.required_hostnames
      puts "Test: #{test_object.class.to_s}::#{method_name} got a score of: #{score}"
      [test_object, score]
    end
  end

end

class BackendClient

  MAX_LOGFILE_SIZE = 1*1024*1024

  def initialize(testrun_id, basedir, log)
    @testrun_id = testrun_id
    @basedir = basedir
    @log = log
    @factory_client = FactoryClient.new(@log)
    @sanitizer = nil
    @valgrind = false
    @durations = {}
    @durations.default = 1500
  end

  def initialize_testrun(test_objects)
    # Initialize Factory with test cases.
    response = @factory_client.initialize_testrun(@testrun_id, test_objects)
    @durations = response[:durations]
    @sanitizer = response[:sanitizer]
    @valgrind = response[:valgrind]
  end

  def sort_testcases(test_objects)
    @log.info("Sorting tests")
    SimpleSystestSorter.new(@durations, test_objects).sort
  end

  def use_sanitizer
    @sanitizer
  end

  def use_valgrind
    @valgrind
  end

  def test_running(testcase, testmethod)
    @factory_client.report_test_running(@testrun_id, testcase, testmethod)
  end

  def test_finished(testcase, test_result)
    testdata = []
    status = test_result.status
    if status == "success"
      @log.debug("Saving performance data")
      dir = testcase.dirs.resultoutput
      Dir.foreach(dir) do |filename|
        next if filename =~ /^\./
        path = File.join(dir, filename)
        if filename == "perf"
          testdata.concat(get_perf_data(path))
        elsif filename == "performance"
          testdata.concat(get_performance_results(path))
        end
      end
    end

    @log.debug("Gathering log files")
    testdata.concat(get_logfiles(test_result))
    @log.debug("Gathering core dumps")
    testdata.concat(get_coredumps(test_result))

    @log.debug("Passing data to factory")
    @factory_client.report_test_finished(@testrun_id, testcase, test_result, get_error_message(test_result), testdata)
  end

  private

  def get_perf_data(path)
    testdata = []
    index = {}
    Dir.foreach(path) do |node_dir|
      next if node_dir =~ /^\./
      index[node_dir] = {}
      node_dir_path = File.join(path, node_dir)
      Dir.foreach(node_dir_path) do |file|
        next if file =~ /^\./
        file_path = File.join(node_dir_path, file)
        name = node_dir + '_' + file
        puts "Save perf data for " + name + " (from " + file_path + ")"
        index[node_dir][file] = name
        testdata.push({
                          "name" => name,
                          "content" => get_capped_log_content(file_path)
                      })
      end
    end
    if not index.empty?
      testdata.push({
                        "name" => "perf",
                        "content" => index.to_json
                    })
    end
    testdata
  end

  def get_error_message(test_result)
    error_message = ""
    if test_result.failure_count > 0
      error_message = test_result.failures[0].message
    elsif test_result.error_count > 0
      error_message = test_result.errors[0].long_desc
    elsif test_result.coredumps.size > 0
      error_message = "Test caused core dumps in:\n#{test_result.coredumps.values.flatten.uniq.map {|d| d.binaryfilename}.join(', ')}"
    end
    error_message
  end

  def get_capped_log_content(path)
    if path =~ /\.gz$/
      Zlib::GzipReader.open(path) do |zip|
        content = zip.read(MAX_LOGFILE_SIZE)
      end
    else
      content = IO.read(path, MAX_LOGFILE_SIZE)
    end
    content = "Factory could not find this logfile : #{path}" unless content

    if content.size >= MAX_LOGFILE_SIZE
      content.concat("\nFactory has stored only #{MAX_LOGFILE_SIZE} bytes of this log due to log size limitations.")
    end
    content.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "?")
  end


  def get_performance_results(path)
    testdata = []
    Dir.foreach(path) do |file|
      next if file =~ /^\./
      perfpath = File.join(path, file)
      testdata.push({
                        "name" => "performance",
                        "content" => get_capped_log_content(perfpath)
                    })
    end

    testdata
  end

  def get_logfiles(test_result)
    testdata = []
    test_result.logfiles.each do |name, path|
      #@log.debug("Looking at log file #{name} located at #{path}")
      begin
        content = get_capped_log_content(path)
      rescue
        content = ""
      end
      testdata.push({
                        "name" => name,
                        "content" => content
                    })
    end
    testdata
  end

  def get_coredumps(test_result)
    testdata = []
    basedir_path = Pathname.new(@basedir)
    test_result.coredumps.each do |hostname, coredumplist|
      coredumps = []
      coredumplist.each do |coredump|
        coredump_path = Pathname.new(coredump.coredir + "/" + coredump.corefilename)
        coredumps.push({
                           "stacktrace" => coredump.stacktrace,
                           "core" => coredump_path.relative_path_from(basedir_path)
                       })
      end
      testdata.push({
                        "name" => "coredumps",
                        "content" => coredumps
                    })
    end
    testdata
  end

end
