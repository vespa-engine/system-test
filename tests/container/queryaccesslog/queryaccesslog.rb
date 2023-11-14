# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'timeout'
require 'search_container_test'
require 'app_generator/container_app'
require 'app_generator/http'
require 'environment'

class QueryAccessLog < SearchContainerTest

  MAX_ATTEMPTS = 5

  def setup
    set_owner("bjorncs")
    set_description("QueryAccessLog log rotation and symlinks are tested for multiple qrservers " +
                    "on the same node. Log rotation time is set to one minute. Both symlinks and old " +
                    "logfiles are tested for correctness after rotation.")
    app = ContainerApp.new.sd(SEARCH_DATA+"music.sd").
      container(new_container("a")).
      container(new_container("b", 4090)).
      container(new_container("c", 4100))
    deploy_app(app)
    start
  end

  def qrs(cluster, idx='0')
    old = vespa.qrs[cluster]
    if old
      return old.qrserver[idx]
    end
    return vespa.container["#{cluster}/#{idx}"]
  end

  def new_container(clusterName, port=4080)
    Container.new(clusterName).
      http(Http.new.server(Server.new(clusterName, port))).
      component(AccessLog.new("vespa").
                fileNamePattern(Environment.instance.vespa_home + "/logs/vespa/access/QueryAccessLog.#{clusterName}.%Y%m%d%H%M%S").
                symlinkName("QueryAccessLog.#{clusterName}").
                rotationInterval("0 1 ...")).
      search(Searching.new)
  end

  def test_querylog
    Timeout.timeout(30) do
      ensure_query_log_files_exist
    end

    # dummy assignment to declare variables in correct scope; assigned and used further down
    logname_a_t0 = ""
    logname_b_t0 = ""
    logname_c_t0 = ""

    puts "Issuing first set of queries"

    successful_match_no_log_rotation = false
    Timeout.timeout(50) do
      # log rotation may interfere with our matching, so we might have to retry
      until successful_match_no_log_rotation do
        logname_a_t0 = get_real_qrs_logname('a')
        logname_b_t0 = get_real_qrs_logname('b')
        logname_c_t0 = get_real_qrs_logname('c')

        search('blues', 0, {}, true, :cluster => 'a')
        search('chicago', 0, {}, true, :cluster => 'b')
        search('female', 0, {}, true, :cluster => 'c')

        attempt = 1
        # assert query log contents, but deal with unintended interference from log rotation
        # (this code would be a lot prettier if matching for file content were separated from asserting)
        begin
          # give the jdisc container some time to write the access log to disk
          sleep 5

          # assert that the correct logfiles contain the correct queries
          assert_match(/blues/, get_qrs_log('a'))
          assert_match(/chicago/, get_qrs_log('b'))
          assert_match(/female/, get_qrs_log('c'))

          # assert that the logfiles do not contain the other qrserver's queries
          assert_no_match(/chicago|female/, get_qrs_log('a'))
          assert_no_match(/blues|female/, get_qrs_log('b'))
          assert_no_match(/blues|chicago/, get_qrs_log('c'))

          # getting this far means we had a successful match, but was it without log rotation interference?
          log_a_untouched = get_real_qrs_logname('a') == logname_a_t0
          log_b_untouched = get_real_qrs_logname('b') == logname_b_t0
          log_c_untouched = get_real_qrs_logname('c') == logname_c_t0
          successful_match_no_log_rotation = log_a_untouched && log_b_untouched && log_c_untouched

        rescue AssertionFailedError
          log_a_untouched = get_real_qrs_logname('a') == logname_a_t0
          log_b_untouched = get_real_qrs_logname('b') == logname_b_t0
          log_c_untouched = get_real_qrs_logname('c') == logname_c_t0
          if log_a_untouched && log_b_untouched && log_c_untouched then
            if attempt <= MAX_ATTEMPTS
              puts "Attempt #{attempt} failed - recent query is still not written to the access log"
              attempt = attempt + 1
            else
              # no log rotation detected => no reason the assertions shouldn't be okay
              raise
            end
          end
        end

        if !successful_match_no_log_rotation then
          puts "Log rotation interference detected, retrying"
        end
      end
    end

    puts "First set of queries found OK in query log"

    Timeout.timeout(70) do
      await_log_rotation
    end

    puts "Issuing second set of queries"

    successful_match_no_log_rotation = false
    Timeout.timeout(50) do
      # log rotation may interfere with our matching, so we might have to retry
      until successful_match_no_log_rotation do
        logname_a_t1 = get_real_qrs_logname('a')
        logname_b_t1 = get_real_qrs_logname('b')
        logname_c_t1 = get_real_qrs_logname('c')

        # these queries should go to the new logfiles
        # using just_do_query to save processing time, trying make them happen within the same second
        search('classic', 0, {}, true, :cluster => 'a')
        search('electric', 0, {}, true, :cluster => 'b')
        search('contemporary', 0, {}, true, :cluster => 'c')

        attempt = 1
        # assert query log contents, but deal with unintended interference from log rotation
        # (this code would be a lot prettier if matching for file content were separated from asserting)
        begin
          # give the jdisc container some time to write the access log to disk
          sleep 5

          # assert that the correct logfiles contain the correct queries
          assert_match(/classic/, get_qrs_log('a'))
          assert_match(/electric/, get_qrs_log('b'))
          assert_match(/contemporary/, get_qrs_log('c'))

          # assert that the logfiles do not contain the other qrserver's queries
          assert_no_match(/electric|contemporary/, get_qrs_log('a'))
          assert_no_match(/classic|contemporary/, get_qrs_log('b'))
          assert_no_match(/classic|electric/, get_qrs_log('c'))

          # getting this far means we had a successful match, but was it without log rotation interference?
          log_a_untouched = get_real_qrs_logname('a') == logname_a_t1
          log_b_untouched = get_real_qrs_logname('b') == logname_b_t1
          log_c_untouched = get_real_qrs_logname('c') == logname_c_t1
          successful_match_no_log_rotation = log_a_untouched && log_b_untouched && log_c_untouched

        rescue AssertionFailedError
          log_a_untouched = get_real_qrs_logname('a') == logname_a_t1
          log_b_untouched = get_real_qrs_logname('b') == logname_b_t1
          log_c_untouched = get_real_qrs_logname('c') == logname_c_t1
          if log_a_untouched && log_b_untouched && log_c_untouched then
            if attempt <= MAX_ATTEMPTS
              puts "Attempt #{attempt} failed - recent query is still not written to the access log"
              attempt = attempt + 1
            else
              # no log rotation detected => no reason the assertions shouldn't be okay
              raise
            end
          end
        end

        if !successful_match_no_log_rotation then
          puts "Log rotation interference detected, retrying"
        end
      end
    end

    puts "Second set of queries found OK in query log"

    qrsnode = qrs('a', '0')
    olfa = qrsnode.execute("cat #{logname_a_t0} 2>/dev/null || zstdcat < #{logname_a_t0}.zst")
    olfb = qrsnode.execute("cat #{logname_b_t0} 2>/dev/null || zstdcat < #{logname_b_t0}.zst")
    olfc = qrsnode.execute("cat #{logname_c_t0} 2>/dev/null || zstdcat < #{logname_c_t0}.zst")

    # assert that the old logfiles contain the same information as before rotation
    assert_match(/blues/, olfa)
    assert_match(/chicago/, olfb)
    assert_match(/female/, olfc)

    # assert that the old logfiles contain the same information as before rotation
    assert_no_match(/chicago|female/, olfa)
    assert_no_match(/blues|female/, olfb)
    assert_no_match(/blues|chicago/, olfc)
  end

  def ensure_query_log_files_exist
    puts "Ensuring query log files exist"
    search('initial_query_a', 0, {}, true, :cluster => 'a')
    search('initial_query_b', 0, {}, true, :cluster => 'b')
    search('initial_query_c', 0, {}, true, :cluster => 'c')

    all_logs_rotated = false
    until get_querylog_timestamp('a') && get_querylog_timestamp('b') && get_querylog_timestamp('c') do
      puts "Awaiting log files' existence"
      sleep 1
    end
    puts "Query log files detected"
  end

  def await_log_rotation
    log_a_t0 = get_querylog_timestamp('a')
    log_b_t0 = get_querylog_timestamp('b')
    log_c_t0 = get_querylog_timestamp('c')

    all_logs_rotated = false
    until all_logs_rotated do
      puts "Awaiting log rotation"

      search('fill_query_awaiting_log_rotation_a', 0, {}, true, :cluster => 'a')
      search('fill_query_awaiting_log_rotation_b', 0, {}, true, :cluster => 'b')
      search('fill_query_awaiting_log_rotation_c', 0, {}, true, :cluster => 'c')

      sleep 1

      log_a_current = get_querylog_timestamp('a')
      log_b_current = get_querylog_timestamp('b')
      log_c_current = get_querylog_timestamp('c')

      logfiles_timestamps = [ log_a_current, log_b_current, log_c_current ]

      some_rotation_observed = (log_a_current != log_a_t0) || (log_b_current != log_b_t0) || (log_c_current != log_c_t0)
      logfiles_have_roughly_same_timestamp = (logfiles_timestamps.max - logfiles_timestamps.min) < 10
      all_logs_rotated = some_rotation_observed && logfiles_have_roughly_same_timestamp
    end

    puts "Log rotation detected"
  end

  def get_qrs_log(cluster)
    qrs(cluster, '0').readfile(get_qrs_symlink_logname(cluster))
  end

  def get_qrs_symlink_logname(cluster)
    Environment.instance.vespa_home + "/logs/vespa/access/QueryAccessLog.#{cluster}"
  end

  def get_real_qrs_logname(cluster)
    qrs(cluster, '0').resolve_symlink(get_qrs_symlink_logname(cluster))
  end

  def list_qrs_log_files(cluster)
    qrs(cluster, '0').list_files("#{Environment.instance.vespa_home}/logs/vespa/access/*")
  end

  def get_querylog_timestamp(cluster)
    i = 0
    # Loop, as it looks like there might be log rotation at the same time we try to read
    loop do
      log_file_name = get_real_qrs_logname(cluster)
      if log_file_name
        return get_timestamp_from_filename(log_file_name)
      else
        puts "Found no query log for cluster #{cluster}"
        puts list_qrs_log_files(cluster)
      end
      sleep 1
      i = i + 1
      break if i > 5
    end
  end

  def get_timestamp_from_filename(filename)
    filename[-14, 14].to_i
  end

  def teardown
    stop
  end

end
