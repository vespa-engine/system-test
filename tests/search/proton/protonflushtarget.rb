# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'environment'

class ProtonFlushTargetTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    @valgrind=false
  end

  def test_proton_flushing
    set_description("Test that attributes, index, and docsummary are flushed to disk")
    deploy_app(SearchApp.new.
                         sd(selfdir+"test.sd").
                         tune_searchnode({:flushstrategy => {:native => {:component => {:maxage => 20}}}}))
    start
    vespa.adminserver.logctl("searchnode:proton.flushengine.flushengine", "debug=on")
    vespa.adminserver.logctl("searchnode:proton.flushengine.flushengine", "spam=on")
    vespa.adminserver.logctl("searchnode:proton.server.documentdb",       "debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.feedhandler",      "debug=on")
    vespa.adminserver.logctl("searchnode:proton.index.fusionrunner",     "debug=on")
    vespa.adminserver.logctl("searchnode:searchcorespi.index.indexfusiontarget","debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.memoryflush",      "debug=on")

    status = get_dir_status
    # handle slow startup where flushing happens before we can check dir status for the first time
    cnt = 0
    while status["iattr"].size > 0 || status["sattr"].size > 0
      puts "[#{cnt}]: Restarting and cleaning node due to premature flushing"
      puts "Status: #{status}"
      vespa.adminserver.stop_base
      vespa.adminserver.clean_indexes
      vespa.adminserver.start_base
      wait_until_all_services_up
      status = get_dir_status
      cnt += 1
    end

    # nothing flushed yet
    assert_equal(0, status["iattr"].size)
    assert_equal(0, status["sattr"].size)
    assert_equal(0, status["index"].size)
    init_summary_size = status["summary"]
    puts "summary: init size(#{status["summary"]})"

    feed_and_wait_for_docs("test", 2, :file => selfdir + "docs.json")

    assert_files_flushed(90, status, "snapshot-")

    assert_log_matches("Pruned TLS to token 6", 30)
    assert_log_matches("New target, Num flushed: 1", 20)
    feed(:file => selfdir + "docs.5.json")
    assert_hitcount_after_flush
    assert_log_matches(/.*flush\.complete.*memoryindex.*flush\.2/, 60)
    feed(:file => selfdir + "docs.5.json")
    assert_hitcount_after_flush
    assert_log_matches(/.*flush\.complete.*memoryindex.*flush\.3/, 60)
    assert_log_matches(/.*fusion\.start.*flush\.1.*flush\.2.*flush\.3/, 60)
    assert_log_matches(/.*fusion\.complete.*fusion\.3/, 60)
  end

  def assert_hitcount_after_flush
    assert_hitcount("query=sddocname:test&nocache", 6)
    assert_hitcount("query=title:test&nocache", 2)
    assert_hitcount("query=title:title&nocache", 6)
    assert_hitcount("query=sattr:first&nocache", 1)
    assert_hitcount("query=sattr:third&nocache", 4)
  end

  def test_proton_searchnode_flushing
    set_description("Test that trigger flush searchnode commands work")
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").disable_flush_tuning)
    start
    vespa.adminserver.logctl("searchnode:proton.flushengine.flushengine", "debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.documentdb",       "debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.fusionrunner",     "debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.indexfusiontarget","debug=on")
    searchnode = vespa.search["search"].first
    status = get_dir_status
    feed_and_wait_for_docs("test", 2, :file => "#{selfdir}/docs.json")
    searchnode.trigger_flush
    assert_files_flushed(1, status, "snapshot-")

    status_before = get_index_status(searchnode)
    feed_and_wait_for_docs("test", 3, :file => "#{selfdir}/docs.2.json")
    timeout = Time.now + 20
    while (Time.now < timeout) do
      pre = Time.now
      status_after = get_index_status(searchnode)
      post = Time.now
      used = post.to_i * 1000000 + post.usec - pre.to_i * 1000000 - pre.usec
      puts "get_index_status took #{used} us"
#      puts "Size_before(#{status_before.size}), size_after(#{status_after.size})"
      assert_equal(status_before.size, status_after.size)
      assert_equal(status_before, status_after)
#      puts "status_before(#{status_before.size}), status_after(#{status_after.size})"
      sleep 1
    end
    searchnode.trigger_flush
    searchnode.trigger_flush # To make sure that any fusion gets run as well
    status_after = get_index_status(searchnode)
#    puts "status_before(#{status_before.size}), status_after(#{status_after.size})"
    assert_not_equal(status_before, status_after)
  end

  def get_full_path(path)
    "#{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/n0/documents/test/0.ready/#{path}"
  end

  def get_dir_status
    status = Hash.new
    path = get_full_path("attribute/iattr/*")
    status["iattr"] = vespa.adminserver.remote_eval("Dir.glob(\"#{path}\")").sort
    path = get_full_path("attribute/sattr/*")
    status["sattr"] = vespa.adminserver.remote_eval("Dir.glob(\"#{path}\")").sort
    path = get_full_path("index/*")
    status["index"] = vespa.adminserver.remote_eval("Dir.glob(\"#{path}\")")
    path = get_full_path("summary/*.dat") # just checking 1 of 64 files
    files = vespa.adminserver.remote_eval("Dir.glob(\"#{path}\")")
    puts "summary files: " + files.to_s
    status["summary"] = vespa.adminserver.remote_eval("File.stat(\"#{files[0]}\").size")
    return status
  end

  def check_log_status(flush_target)
    if vespa.logserver.log_matches(/.*flush\.complete.*test\.[0-2]\..*\.#{flush_target}/) >= 1
      return true
    else
      puts "Flush target '#{flush_target}' not finished according to log"
      return false
    end
  end

  def check_attr_dir_status(status_arr, flushed, exp_dir, flush_target)
    if (status_arr.size >= 2 and !flushed)
      # 1) The content of status_arr is most times:
      #   [0] = 'attribute/attr_name/meta-info.txt'
      #   [1] = 'attribute/attr_name/snapshot-X'
      # 2) In some few cases when status is fetched at the same time as meta-info.txt is written we have:
      #   [0] = 'attribute/attr_name/meta-info.txt'
      #   [1] = 'attribute/attr_name/meta-info.txt.new'
      #   [2] = 'attribute/attr_name/snapshot-X'
      # 3) We can also have the following if status is fetched right before the snapshot directory is created:
      #   [0] = 'attribute/attr_name/meta-info.txt'
      #   [1] = 'attribute/attr_name/meta-info.txt.new'
      act_dir = status_arr.last
      if (!act_dir.include?("snapshot-")) # Handle scenario 3) as described above, and try again later
        return false
      end
      puts "check_attr_dir_status: exp_dir='#{exp_dir}', act_dir='#{act_dir}'"
      assert(act_dir.include?(exp_dir))
      if (check_log_status(flush_target))
        return true
      end
    end
    return flushed
  end

  def check_dir_status(status_arr, flushed, exp_dir, flush_target)
    if (!status_arr.empty? and !flushed)
      assert_equal(1, status_arr.size)
      assert_equal(exp_dir, status_arr[0])
      if (check_log_status(flush_target))
        return true
      end
    end
    return flushed
  end

  def print_dir_status(status, name, flushed)
    puts "#{name}(#{flushed ? "FLUSHED" : "NOT_FLUSHED"}): [" + status[name].join(",") + "]"
  end

  def assert_files_flushed(timeout, init_status, attr_snapshot)
    status = init_status
    init_summary_size = init_status["summary"]
    iattr_f = false
    sattr_f = false
    index_f = false
    summary_f = false
    for i in 0..timeout do
      puts "**** status #{i} ****"
      status = get_dir_status
      print_dir_status(status, "iattr", iattr_f)
      print_dir_status(status, "sattr", sattr_f)
      print_dir_status(status, "index", index_f)
      iattr_f = check_attr_dir_status(status["iattr"], iattr_f, get_full_path("attribute/iattr/#{attr_snapshot}"), "attribute.flush.iattr")
      sattr_f = check_attr_dir_status(status["sattr"], sattr_f, get_full_path("attribute/sattr/#{attr_snapshot}"), "attribute.flush.sattr")
      index_f = check_dir_status(status["index"], index_f, get_full_path("index/index.flush.1"), "memoryindex.flush")
      summary_f = true if (status["summary"] > init_summary_size and check_log_status("summary"))
      print_dir_status(status, "iattr", iattr_f)
      print_dir_status(status, "sattr", sattr_f)
      print_dir_status(status, "index", index_f)
      puts "summary(#{summary_f ? "F" : "W"}): size(#{status["summary"]})"
      if (iattr_f and sattr_f and index_f and summary_f)
        break
      end
      sleep 2
    end
    assert(iattr_f)
    assert(sattr_f)
    assert(index_f)
    assert(summary_f)
  end

  def get_index_status(searchnode)
    return searchnode.stat_files(get_full_path("**/*/*"), lambda{|x| return x.mtime })
  end

  def teardown
    stop
  end

end
