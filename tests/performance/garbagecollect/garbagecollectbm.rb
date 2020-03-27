# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

# -*- coding: utf-8 -*-
require 'digest'
require 'performance_test'
require 'app_generator/search_app'
require 'document'
require 'document_set'
require 'doc_generator'
require 'thread'
require 'environment'

class GarbageCollectBMTestParams
  attr_reader :label
  attr_reader :perchunk
  attr_reader :minfillwords
  attr_reader :randfillwords
  attr_reader :window
  attr_reader :loops

  def initialize(label, perchunk, minfillwords, randfillwords, window, loops)
    @label = label
    @perchunk = perchunk
    @minfillwords = minfillwords
    @randfillwords = randfillwords
    @window = window
    @loops = loops
  end
end

class GarbageCollectBMDocGenerator
  attr_reader :doc_type

  def initialize(doc_type, id_prefix, uid_prefix, words)
    @doc_type = doc_type
    @id_prefix = id_prefix
    @uid_prefix = uid_prefix
    @words = words
  end

  def generate(doc_begin, num_docs, mints, maxts, mods = [2, 3, 5, 7, 11])
    ds = DocumentSet.new()
    wmods = []
    mods.each do |mod|
      wmod = []
      mod.times do |i|
        wmod.push("w#{mod}w#{i}")
      end
      wmods.push(wmod)
    end
    for i in doc_begin..doc_begin + num_docs - 1 do
      doc = Document.new(@doc_type, @id_prefix + i.to_s)
      w = []
      wmods.each do |wmod|
        w.push(wmod[i % wmod.size])
      end
      filler = []
      nwords = 20 + rand(50)
      nwords.times do
        filler.push(@words[rand(@words.size)])
      end
      ts = mints + rand(maxts - mints)
      doc.add_field("i1", w.join(" "))
      doc.add_field("i2", i.to_s)
      doc.add_field("i3", filler.join(" "))
      doc.add_field("ts", ts)
      ds.add(doc)
    end
    return ds
  end

  def generate_canaries(canariusers, peruid, ts)
    ds = DocumentSet.new()
    i = 1000000000
    canariusers.each do |uid|
      peruid.times do |p|
        doc = Document.new(@doc_type, @uid_prefix + uid.to_s + ":" + i.to_s)
        w = []
        w.push("canary")
        w.push("canary" + uid.to_s)
        doc.add_field("i1", w.join(" "))
        doc.add_field("i2", i.to_s)
        doc.add_field("ts", ts)
        ds.add(doc)
        i = i + 1
      end
    end
    return ds
  end
end

class GarbageCollectBMPollHits
  def initialize(testcase, mutex, cv, qrserver, canaryusers, peruid)
    @testcase = testcase
    @mutex = mutex
    @cv = cv
    @qrserver = qrserver
    @canaryusers = canaryusers
    @active = false
    @thread = nil
    @peruid = peruid
    @canaries = peruid * @canaryusers.size()
    @starttime = nil
    @endtime = nil
  end

  def puts(str)
    @testcase.puts(str)
  end

  def hcs
    "/search/?query=sddocname:garbagecollectbm&nocache&hits=0&ranking=unranked&format=xml"
  end

  def canary_hcs
    "/search/?query=i1:canary&nocache&hits=0&ranking=unranked&format=xml"
  end

  def canary_uid_hcs(uid)
    "/search/?query=i1:canary#{uid}&nocache&hits=0&ranking=unranked&format=xml"
  end

  def hitcount
    @qrserver.search(hcs).hitcount
  end

  def canary_hitcount
    @qrserver.search(canary_hcs).hitcount
  end

  def canary_uid_hitcount(uid)
    @qrserver.search(canary_uid_hcs(uid)).hitcount
  end

  def showhits(ispollthread = false, verbose = false)
    chc = canary_hitcount()
    if ispollthread
      if chc != @canaries && @starttime.nil?
        puts "Setting poll gc starttime, #{chc} of #{@canaries} canaries left"
        @mutex.synchronize do
          @starttime = Time.new
        end
      end
      if chc == 0 && @endtime.nil?
        puts "Setting poll gc endtime, 0 of #{@canaries} canaries left"
        @mutex.synchronize do
          @endtime = Time.new
        end
      end
      return unless verbose
    end
    hcv = []
    hcv.push(chc)
    @canaryusers.each do |uid|
      chc = canary_uid_hitcount(uid)
      hcv.push(chc)
    end
    hc = hitcount()
    chcs = hcv.join(" ")
    if ispollthread
      puts "Polling #{hc} hits, canaries #{chcs}"
    else
      puts "Got #{hc} hits, canaries #{chcs}"
    end
  end

  def gcstarted
    @mutex.synchronize do
      return !@starttime.nil?
    end
  end

  def hasgctime
    @mutex.synchronize do
      return !@starttime.nil? && !@endtime.nil?
    end
  end

  def inactive
    @mutex.synchronize do
      return !@active
    end
  end

  def gctime
    return -1.0 unless hasgctime
    @mutex.synchronize do
      return @endtime.to_f - @starttime.to_f
    end
  end

  def pollhits(verbose = false)
    # puts "#### starting pollhits thread ####"
    iters = 0
    wantbreak = false
    while true
      @mutex.synchronize do
        wantbreak = !@active
      end
      if wantbreak
        # puts "#### breaking out of pollhits thread ####"
        break
      end
      # puts "#### running pollhits thread ####"
      showhits(true, verbose)
      sleep 0.2
      iters = iters + 1
    end
    # puts "#### ending pollhits thread ####"
  end

  def create_thread(verbose = false)
    # puts "########## create pollhits thread ##########"
    @mutex.synchronize do
      @active = true
    end
    thread = Thread.new(verbose) do |pverbose|
      begin
        pollhits(pverbose)
      rescue Exception => e
        puts "pollhits thread got exception"
        puts e.message
        puts e.backtrace.inspect
      rescue
        puts "pollhits thread got unknown exception"
      ensure
        @mutex.synchronize do
          @active = false
        end
      end
    end
    @mutex.synchronize do
      @thread = thread
    end
  end

  def join
#    puts "### join 1 ###"
    @mutex.synchronize do
      return if @thread.nil?
    end
#    puts "### join 2 ###"
    @mutex.synchronize do
      @active = false
      @cv.signal
    end
#    puts "### join 3 ###"
    @thread.join
    @thread = nil
#    puts "### join 4 ###"
  end
end

class GarbageCollectBM < PerformanceTest

  TAG = "tag"
  PASS = "pass"
  GCTIME = "gctime"
  TEST_LABEL = "smalldocs-smallwin"

  def setup
    super
    set_owner("toregge")
    set_description("Benchmark performance of garbage collect handling")
    srand(123)
    @doc_type = "garbagecollectbm"
    @id_prefix = "id:test:#{@doc_type}::"
    @uid_prefix = "id:test:#{@doc_type}:n="
    @perchunk = 5000
    @peruid = 2
    @canaryusers = []
    canarybits = 5
    nuid = 1 << canarybits
    for uid in 0..nuid - 1
      ruid = 0
      tuid = uid
      canarybits.times do
        ruid <<= 1
        ruid += 1 if ((tuid & 1) != 0)
        tuid >>= 1
      end
#      @canaryusers.push(ruid)
      @canaryusers.push(uid)
    end
#    Doesn't work properly, signed/unsigned conflict
#    @canaryusers.push(18446744073709551615)
    @canaryusers.push(9223372036854775807)
    # 2 * (32 + 1), i.e. peruid * (nuid + 1)
    @canaries = @peruid * @canaryusers.size()
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    # How long to wait for correct hitcount after restarting node
    @restartwait = 1800
  end

  # Method copied from SearchTest, then mutated
  def redeploy(app)
    deploy_output = deploy_app(app, :no_init_logging => true)
    gen = get_generation(deploy_output).to_i
    vespa.storage["search"].wait_until_content_nodes_have_config_generation(gen)
    return deploy_output
  end

  def get_base_sc(parts)
    SearchCluster.new.
      sd(selfdir + "garbagecollectbm.sd").
      num_parts(parts).
      redundancy(parts > 1 ? 2 : 1).
      ready_copies(parts > 1 ? 2 : 1)
  end

  def get_base_app(sc)
    SearchApp.new.cluster(sc)
  end

  def get_app(sc)
    get_base_app(sc)
  end

  def override_gc_interval(sc, interval = 30)
    sc.garbagecollection(true).garbagecollectioninterval(interval)
  end

  def suffix(label, i)
    "%s-%03d" % [ label, i ]
  end

  def addname(label, i)
    "add-#{suffix(label, i)}"
  end

  def rmname(label, i)
    "rm-#{suffix(label, i)}"
  end

  def gen_data(params)
    label = params.label
    perchunk = params.perchunk
    minfillwords = params.minfillwords
    randfillwords = params.randfillwords
    window = params.window
    loops = params.loops
    if @words.nil?
      puts "generating dictionary"
      @words = StringGenerator.rand_unique_array(5, 10, 100000)
    else
      puts "reusing dictionary"
    end
    words = @words
    dg = GarbageCollectBMDocGenerator.new(@doc_type, @id_prefix, @uid_prefix,
                                          words)
    chunks = window + loops - 1
    tswin = window * perchunk
    tsstart = 0
    chunks.times do |i|
      addname = addname(label, i)
      rmname = rmname(label, i)
      tslim = tsstart + tswin
      docslim = perchunk
      if i + 1 < window
        tslim = tsstart + (i + 1) * perchunk
        docslim = perchunk * (i + 1) / window
      end
      puts "generating #{addname} (#{docslim} docs)"
      docs = dg.generate(i * perchunk, docslim, tsstart, tslim)
      puts "writing #{addname}"
      docs.write_xml(dirs.tmpdir + addname)
      chk = Digest::SHA256.file(dirs.tmpdir + addname).hexdigest
      puts "SHA256(#{addname})= #{chk}"
      histogram = Array.new(i + 1 < window ? i + 1 : window)
      histogram.size.times do |slot|
        histogram[slot] = 0
      end
      docs.documents.each do |document|
        slot = (document.fields["ts"] - tsstart) / perchunk
        if slot >= histogram.size
          raise "Bad histogram slot"
        end
        histogram[slot] = histogram[slot] + 1
      end
      histname = addname + ".histogram"
      puts "writing #{histname}"
      histfile = File.open(dirs.tmpdir + histname, "w")
      histogramstr = histogram.join(" ")
      histfile.write(histogramstr + "\n")
      histfile.close()
      chk = Digest::SHA256.file(dirs.tmpdir + histname).hexdigest
      puts "SHA256(#{histname})= #{chk}"
      puts "writing #{rmname}"
      docs.write_rm_xml(dirs.tmpdir + rmname)
      chk = Digest::SHA256.file(dirs.tmpdir + rmname).hexdigest
      puts "SHA256(#{rmname})= #{chk}"
      if i + 1 >= window
        puts "generating #{addname}c"
        canaries = dg.generate_canaries(@canaryusers, @peruid, tsstart)
        puts "writing #{addname}c"
        canaries.write_xml(dirs.tmpdir + addname + "c")
        chk = Digest::SHA256.file(dirs.tmpdir + addname + "c").hexdigest
        puts "SHA256(#{addname}c)= #{chk}"
        tsstart = tsstart + perchunk
      end
    end
  end

  def hcs
    "/search/?query=sddocname:garbagecollectbm&nocache&hits=0&ranking=unranked&format=xml"
  end

  def qrserver
    vespa.container.values.first
  end

  def unregister_pollhits
    @pollhits.join unless @pollhits.nil?
    @pollhits = nil
  end

  def create_pollhits(register = false)
    res = GarbageCollectBMPollHits.new(self, @mutex, @cv,
                                       qrserver, @canaryusers, @peruid)
    if register
      unregister_pollhits
      @pollhits = res
    end
    return res
  end

  def showhits
    create_pollhits().showhits(false, true)
  end

  # Method copied from feeding_and_recovery
  def stop_node_not_working
    vespa.search["search"].first.stop
    vespa.storage["search"].storage["0"].stop
    vespa.storage["search"].distributor["0"].stop
    vespa.storage["search"].storage["0"].wait_for_current_node_state('d', 300)
    vespa.storage["search"].distributor["0"].wait_for_current_node_state('d', 300)
  end

  def stop_node
    @leave_loglevels = true
    vespa.stop_base
    @leave_loglevels = false
  end

  def clean_node
    vespa.search["search"].first.execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/r0/c0")
  end

  # Method copied from feeding_and_recovery
  def start_node_not_working
    vespa.search["search"].first.start
    vespa.storage["search"].storage["0"].start
    vespa.storage["search"].distributor["0"].start
    vespa.storage["search"].storage["0"].wait_for_current_node_state('u', 300)
    vespa.storage["search"].distributor["0"].wait_for_current_node_state('u', 300)
  end

  def start_node
    vespa.start_base
  end

  def restart_node(app, clean = false)
    # TODO: force GC without restart
    stop_node
    clean_node if clean
    deploy_app(app, :no_init_logging => true)
    start_node
    vespa.storage["search"].wait_until_all_services_up(600)
  end

  def redeploy_and_poll(app)
    pollhits = create_pollhits(true)
    pollhits.showhits(false, true)
    pollhits.create_thread(false)
    redeploy(app)
    20000.times do |i|
      wantbreak = pollhits.hasgctime || pollhits.inactive
      if pollhits.gcstarted
        showhits
      else
        if i == 0
          if wantbreak
            puts "Not waiting for GC scan to start"
          else
            puts "Waiting for GC scan to start"
          end
        end
      end
      break if wantbreak
      sleep 1
    end
    unregister_pollhits
    if pollhits.hasgctime
      gctime = pollhits.gctime
      puts "Polled GC time is #{gctime} seconds"
      return gctime
    else
      raise "Failed to get GC time"
      return nil
    end
  end

  def read_histogram(name)
    histfile = File.open(name)
    histogramstr = histfile.readline()
    histfile.close()
    histogram = Array.new
    histogramstr.split.each do |count|
      histogram.push(count.to_i)
    end
    return histogram
  end

  def merge_histograms(histogram, newhistogram)
    while histogram.size < newhistogram.size
      histogram.push(0)
    end
    i = 0
    newhistogram.each do |count|
      histogram[i] = histogram[i] + count
      i = i + 1
    end
  end

  def histogram_sum(histogram)
    sum = 0
    histogram.each do |count|
      sum = sum + count
    end
    return sum
  end

  def gctest(params)
    label = params.label
    perchunk = params.perchunk
    minfillwords = params.minfillwords
    randfillwords = params.randfillwords
    window = params.window
    loops = params.loops
    # gen_data(params)
    canaries = @canaries
    sc = get_base_sc(1)
    app = get_app(sc)
    override_gc_interval(sc, 0)
    restart_node(app, true)
    wait_for_hitcount(hcs, 0, @restartwait)
    preloops = window - 1
    histogram = Array.new(window)
    window.times do |slot|
      histogram[slot] = 0
    end
    docs = 0
    oldhitcount = 0
    preloops.times do |i|
      addname = addname(label, i)
      subhistogram = read_histogram(dirs.tmpdir + addname + ".histogram")
      subdocs = histogram_sum(subhistogram)
      puts "Feeding #{addname} (#{subdocs} docs)"
      feed(:file => dirs.tmpdir + addname)
      merge_histograms(histogram, subhistogram)
      docs = histogram_sum(histogram)
      assert(docs == oldhitcount + subdocs)
      puts "#{subdocs} docs according to #{addname}.histogram => #{docs} docs"
      wait_for_hitcount(hcs, docs)
      oldhitcount = docs
    end
    tsstart = 0
    loops.times do |j|
      i = preloops + j
      addname = addname(label, i)
      puts "Hitcount before feed is #{oldhitcount}"
      subhistogram = read_histogram(dirs.tmpdir + addname + ".histogram")
      subdocs = histogram_sum(subhistogram)
      puts "Feeding #{addname} (#{subdocs} docs)"
      feed(:file => dirs.tmpdir + addname)
      merge_histograms(histogram, subhistogram)
      docs = histogram_sum(histogram)
      assert(docs == oldhitcount + subdocs)
      puts "#{subdocs} docs according to #{addname}.histogram => #{docs} docs"
      tmphitcount = docs
      wait_for_hitcount(hcs, tmphitcount)
      puts "Feeding #{addname}c"
      feed(:file => dirs.tmpdir + addname + "c")
      wait_for_hitcount(hcs, tmphitcount + canaries)
      showhits
      ts = tsstart + perchunk
      tsm1 = ts - 1
      sc = get_base_sc(1)
      app = get_app(sc)
      sc.doc_type("garbagecollectbm", "garbagecollectbm.ts > #{tsm1}").
        garbagecollection(true)
      override_gc_interval(sc)
      gctime1 = redeploy_and_poll(app)
      write_report([parameter_filler(TAG, "gc-#{label}"),
                    parameter_filler(PASS, j.to_s),
                    metric_filler(GCTIME, gctime1)])
      histogram.delete_at(0)
      histogram.push(0)
      docs = histogram_sum(histogram)
      newhitcount = create_pollhits().hitcount
      puts "Hitcount after GC is now #{newhitcount}, expected #{docs}"
      if newhitcount != docs
        puts "Canary protection insufficient, " +
          "waiting for correct hitcount #{docs}"
        wait_for_hitcount(hcs, docs)
        newhitcount = docs
        puts "Extra canary failure wait done"
      end
      removeddocs = tmphitcount - newhitcount
      suffix = suffix(label, j)
      puts "gctime #{suffix} for removing #{removeddocs} of #{tmphitcount} documents is #{gctime1}"
      sc = get_base_sc(1)
      app = get_app(sc)
      override_gc_interval(sc, 0)
      restart_node(app, false)
      wait_for_hitcount(hcs, newhitcount, @restartwait)
      puts "Feeding #{addname}c"
      feed(:file => dirs.tmpdir + addname + "c")
      wait_for_hitcount(hcs, newhitcount + canaries)
      sc = get_base_sc(1)
      app = get_app(sc)
      sc.doc_type("garbagecollectbm", "garbagecollectbm.ts > #{tsm1}").
        garbagecollection(true)
      override_gc_interval(sc)
      gctime1 = redeploy_and_poll(app)
      write_report([parameter_filler(TAG, "gc-#{label}-rescan"),
                    parameter_filler(PASS, j.to_s),
                    metric_filler(GCTIME, gctime1)])
      puts "gctime #{suffix}-rescan for removing 0 of #{newhitcount} documents is #{gctime1}"
      wait_for_hitcount(hcs, newhitcount)
      sc = get_base_sc(1)
      app = get_app(sc)
      override_gc_interval(sc, 0)
      restart_node(app, false)
      wait_for_hitcount(hcs, newhitcount, @restartwait)
      oldhitcount = newhitcount
      tsstart = ts
    end
    chunks = window + loops - 1
    chunks.times do |i|
      rmname = rmname(label, i)
      puts "Feeding #{rmname}"
      feed(:file => dirs.tmpdir + rmname)
    end
    wait_for_hitcount(hcs, 0)
  end

  def make_graphs
    graphs = [ ]
    2.times do |rescan|
      rescanstr = rescan != 0 ? "-rescan" : ""
      tagstr = "gc-" + TEST_LABEL + rescanstr
      graphs.push({ :title => "Historic gctime (sec) for #{TAG}='#{tagstr}', #{PASS}==0",
                    :filter => { TAG => tagstr, PASS => "0"},
                    :x => PASS,
                    :y => GCTIME,
                    :historic => true,
                    :y_min => 1.5,
                    :y_max => 27
                  })
    end
    graphs
  end

  def test_garbage_collect_bm
    @graphs = make_graphs
    puts "Before Deploy: #{@vespa.to_s}\n"
    perchunk = @perchunk
    canaries = @canaries
    smalldocparams = [ 2, 5 ]
    smallwin = 2
    loops = 5
    ssparams = GarbageCollectBMTestParams.new(TEST_LABEL,
                                              perchunk,
                                              smalldocparams[0],
                                              smalldocparams[1],
                                              smallwin, loops)
    gen_data(ssparams)
    sc = get_base_sc(1)
    app = get_app(sc)
    override_gc_interval(sc, 0)
    deploy_app(app)
    puts "After Deploy: #{@vespa.to_s}\n"
    start

    # proton = vespa.search["search"].first
    # proton.logctl("searchnode:proton.server.storeonlyfeedview", "all=on")
    # proton.logctl("searchnode:proton.persistenceengine.persistenceengine",
    # "all=on")
    gctest(ssparams)
  end

  def teardown
    unregister_pollhits
    super
  end

end
