# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'
require 'document_set'

class GroupingTest < PerformanceTest

  def timeout_seconds
    return 7200
  end

  def initialize(*args)
    super(*args)
    @warmup = false
  end

  def setup
    super
    set_owner("bjorncs")
    queryfile_name = 'grouping_queries.txt'
    @local_queryfile = dirs.tmpdir + queryfile_name
    @remote_dir = "#{Environment.instance.vespa_home}/tmp/performancetest_grouping/"
    @queryfile = @remote_dir + queryfile_name
    @feedfile = dirs.tmpdir + 'grouping_feed.xml'
    @sdfile = dirs.tmpdir + 'groupingbench.sd'
  end

  def test_grouping_levels
    attr_prefix = "a"
    num_attr = 10
    setup_grouping_test(attr_prefix, 10000, num_attr, 5)
    qrserver = @vespa.container.values.first
    for lvl in 1..5
      generatequeries(File.new(@local_queryfile, "w"),
                      attr_prefix, 1, num_attr, lvl)
      vespa.adminserver.copy(@local_queryfile, @remote_dir)
      run_fbench_ntimes(qrserver, 1, 10, 3, [parameter_filler("grouping_level", lvl)])
    end
  end

  def test_grouping_parallel
    attr_prefix = "a"
    num_attr = 10
    num_levels = 2
    setup_grouping_test(attr_prefix, 10000, num_attr, 5)
    qrserver = @vespa.container.values.first
    for num_par in 1..6
      generatequeries(File.new(@local_queryfile, "w"),
                      attr_prefix, num_par, num_attr, num_levels)
      vespa.adminserver.copy(@local_queryfile, @remote_dir)
      run_fbench_ntimes(qrserver, 1, 10, 3, [parameter_filler("grouping_level", num_levels), parameter_filler("grouping_parallel", num_par)])
    end
  end

  def test_grouping_count_many_groups
    set_owner("bjorncs")
    run_grouping_count_many_groups_test(false)
  end

  def test_grouping_count_many_groups_paged_attributes
    set_owner("bjorncs")
    run_grouping_count_many_groups_test(true)
  end

  def run_grouping_count_many_groups_test(paged_attributes)
    attr_prefix = "a"
    num_docs = 100000
    num_attr = 3
    num_unique = 100000
    setup_grouping_test(attr_prefix, num_docs, num_attr, num_unique, paged_attributes)

    query = "/?query=sddocname:groupingbench&nocache&hits=0&format=json&" +
      "select=all(group(a0)output(count()))"
    puts "Verify single level grouping"
    tree = search(query).json
    puts "Group count is %d" % tree["root"]["children"][0]["fields"]["count()"]
    assert_equal(98637, tree["root"]["children"][0]["fields"]["count()"])

    query = "/?query=sddocname:groupingbench&nocache&hits=0&format=json&" +
      "select=all(group(a0)max(10)output(count())" +
      " each(group(a0) output(count())))"
    puts "Verify Multilevel grouping"
    tree = search(query).json
    puts "Group count is %d" % tree["root"]["children"][0]["fields"]["count()"]
    assert_equal(98637, tree["root"]["children"][0]["fields"]["count()"])

    qrserver = @vespa.container.values.first
    File.open(@local_queryfile, "w") { |file|
      file.write("/search/?query=sddocname:groupingbench&nocache&hits=0&" +
                 "select=all(group(a0)output(count()))")
    }
    vespa.adminserver.copy(@local_queryfile, @remote_dir)
    puts "Warmup"
    run_fbench(qrserver, 1, 30, [parameter_filler("legend", "warmup")])
    puts "Single level"
    # Temporary debugging to see if we are somehow downclocking the CPUs merely by looking
    # at certain AVX-512 instructions in the wrong way.
    perf_dump = ""
    perf_t = Thread.new {
      search_node = vespa.search['search'].first
      proton_pid = search_node.get_pid
      if search_node.execute('uname -m').strip == 'x86_64'
        perf_stat_cmd = "perf stat -I 1000 --pid=#{proton_pid} -e '" +
                        "cpu/event=0x28,umask=0x07,name=core_power_lvl0_turbo_license/," +
                        "cpu/event=0x28,umask=0x18,name=core_power_lvl1_turbo_license/," +
                        "cpu/event=0x28,umask=0x20,name=core_power_lvl2_turbo_license/' sleep 15 2>&1"
        search_node.execute(perf_stat_cmd, :exceptiononfailure => false) # Just dump to test output
      else
        puts "Search node is not running on an x86-64 CPU, not dumping power license PMUs"
      end
    }
    @perf_recording = 'some'
    profiler_start
    run_fbench(qrserver, 1, 60, [parameter_filler("legend", "single_level")])
    node = vespa.search["search"].first
    profiler_report('single_level')
    write_report([metric_filler("memory.rss", node.memusage_rss(node.get_pid)),
                  parameter_filler("legend", "single_level")])
    puts "Single level mem usage: #{node.memusage_rss(node.get_pid)}"
    perf_t.join

    File.open(@local_queryfile, "w") { |file|
      file.write("/search/?query=sddocname:groupingbench&nocache&hits=0&" +
                 "select=all(group(a0)max(10000)output(count())" +
                 "each(group(a1)output(count())))")
    }
    vespa.adminserver.copy(@local_queryfile, @remote_dir)
    puts "Multilevel"
    profiler_start
    run_fbench(qrserver, 1, 60, [parameter_filler("legend", "multilevel")])
    profiler_report('multilevel')
    write_report([metric_filler("memory.rss", node.memusage_rss(node.get_pid)),
                  parameter_filler("legend", "multilevel")])
    puts "Multilevel mem usage: #{node.memusage_rss(node.get_pid)}"
  end

  def setup_grouping_test(attr_prefix, num_docs, num_attr, num_unique, paged_attributes=false)
    generatefeed(File.new(@feedfile, "w"), num_docs, attr_prefix, num_attr,
                 num_unique)
    generatesd(File.new(@sdfile, "w"), attr_prefix, num_attr, paged_attributes)

    deploy_app(SearchApp.new.sd(@sdfile).search_dir(selfdir + 'search'))
    start
    feed_and_wait_for_docs("groupingbench", num_docs, :file => @feedfile)
  end

  def generatesd(f, attr_prefix, num_string_attr, paged_attributes=false)
    sd = "search groupingbench {\n"
    sd += "    document groupingbench {\n"
    num_attr = 0
    for attr in num_attr..(num_attr + num_string_attr - 1)
      sd += "        field #{attr_prefix}#{attr} type string {\n"
      sd += "            indexing: attribute | summary\n"
      if paged_attributes
        sd += "            attribute: paged\n"
      end
      sd += "        }\n"
    end
    sd += "    }\n"
    sd += "}"
    f.puts(sd)
    f.close
  end

  def generatefeed(filename, num_docs, attr_prefix, num_attr, num_unique)
    docs = DocumentSet.new
    for i in 0..(num_docs - 1)
      doc = Document.new("id:groupingbench:groupingbench::#{i}")
      somevalue = (i % num_unique)
      for attr in 0..(num_attr - 1)
        doc.add_field("a#{attr}", "val_#{attr}_#{somevalue}")
      end
      docs.add(doc)
    end
    docs.write_json(filename)
  end

  def incattr(attr, numinc, num_attr)
    return ((attr + numinc) % num_attr)
  end

  def generatequeries(f, attr_prefix, num_parallel, num_attr, num_levels)
    query = "/search/?query=sddocname:groupingbench&nocache&hits=0&select="
    if (num_parallel > 1)
      query += "all("
    end

    for req in 0..(num_parallel - 1)
      query += "all("
      startattr = req % num_attr
      endattr = incattr(startattr, num_levels, num_attr)
      attrcount = 0
      while startattr != endattr do
        attrname = "#{attr_prefix}#{startattr}"
        query += "group(#{attrname})each("
        startattr = incattr(startattr, 1, num_attr)
        attrcount += 1
      end
      assert_equal(attrcount, num_levels)
      query += "output(count())"
      for level in 0..(num_levels - 1)
        query += ")"
      end
      query += ")"
    end

    if (num_parallel > 1)
      query += ")"
    end
    f.puts(query)
    f.close
  end

  def teardown
    vespa.adminserver.execute("rm -rf #{@remote_dir}")
    `rm -f #{@local_queryfile}`
    `rm -f #{@feedfile}`
    `rm -f #{@sdfile}`
    super
  end
end
