# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class NearestNeighborPerformanceTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    1800
  end

  def setup
    super
    set_description('Test various cases with nearest neighbor search')
    set_owner("arnej")
  end

  def file_in_tmp(file_name)
    dirs.tmpdir + file_name
  end

  Q = '%22'
  LB = '[%7B'
  RB = '%7D]'
  PRE = 'select+*+from+sources+*+where+'
  NNS = 'nearestNeighbor(dvector,qvector);'
  RFQV = 'ranking.features.query(qvector)'

  def write_nns_queries(qfn, tHits)
    File.open(qfn, 'w') do |f|
      (1..99999).each do |num|
        v = "[#{num}#{@rnd511vec}]"
        label = "#{Q}label#{Q}:#{Q}mynns#{Q}"
        t_ann = "#{Q}targetNumHits#{Q}:#{tHits}"
        annotations = "#{LB}#{label},#{t_ann}#{RB}"
        yql = "#{PRE}#{annotations}#{NNS}"
        f.puts("/search/?yql=#{yql}&#{RFQV}=#{v}")
      end
    end
  end

  def write_doc_queries(qfn)
    File.open(qfn, 'w') do |f|
      (1..99999).each do |num|
        v = "[#{num}#{@rnd511vec}]"
        f.puts("/search/?query=title:doc&#{RFQV}=#{v}")
      end
    end
  end

  def gen_511_randoms
    v = ""
    (1..511).each do
      v += ",#{Random.rand(100)}"
    end
    return v
  end

  def test_nearest_neighbor
    app = SearchApp.new.monitoring("vespa", 60).
          sd(selfdir+"foobar.sd").
          search_dir(selfdir+"search").
          container(Container.new("combinedcontainer").
                    search(Searching.new).
                    docproc(DocumentProcessing.new).
                    gateway(ContainerDocumentApi.new)).
          indexing("combinedcontainer").
          threads_per_search(1)
    deploy_app(app)
    @graphs = get_graphs()
    start

    puts "GENERATING QUERIES"
    # queries
    @rnd511vec = gen_511_randoms
    qf1 = file_in_tmp('alldoc-queries.txt')
    qf2 = file_in_tmp('nnsitem-10-queries.txt')
    qf3 = file_in_tmp('nnsitem-100-queries.txt')
    qf4 = file_in_tmp('nnsitem-1000-queries.txt')
    write_doc_queries(qf1)
    write_nns_queries(qf2, 10)
    write_nns_queries(qf3, 100)
    write_nns_queries(qf4, 1000)
    puts "DONE QUERY GENERATING"

    # feed
    puts "FEEDING DOCUMENTS"
    node = vespa.adminserver
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out")
    assert_equal(0, exitcode)
    (exitcode, output) = execute(node, "#{tmp_bin_dir}/a.out | vespa-feed-perf")
    assert_equal(0, exitcode)
    wait_for_hitcount("sddocname:foobar", 100000, 30)
    puts "DONE FEEDING"

    node.execute('vespa-proton-cmd --local triggerFlush')
    node.execute('vespa-proton-cmd --local triggerFlush')

    run_benchmarks(qf1, 'alldoc', false)
    run_benchmarks(qf2, 'nns_10', true)
    run_benchmarks(qf3, 'nns_100', true)
    run_benchmarks(qf4, 'nns_1000', true)
  end

  def run_benchmarks(query_file, legend, want_rawscore)
    # Basic search
    qrserver = @vespa.container["combinedcontainer/0"]
    qd = dirs.tmpdir + "qd"
    qrserver.copy(query_file, qd)
    qf = qd + "/" + File.basename(query_file)
    puts "qf: #{qf}"

    run_fbench(qrserver, 48, 20, qf, legend + '_simple')
    run_fbench(qrserver, 48, 20, qf, legend + '_joinsq',     "&ranking=joinsqdiff")
    run_fbench(qrserver, 48, 20, qf, legend + '_dotproduct', "&ranking=dotproduct")
    run_fbench(qrserver, 48, 20, qf, legend + '_rawscore',   "&ranking=rawscore") if want_rawscore
  end

  def run_fbench(qrserver, clients, runtime, qf, legend, append_str = "")
    custom_fillers = [
      parameter_filler("legend", legend),
      parameter_filler("recall", "100")
    ]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 10000
    fbench.single_query_file = true
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.append_str = append_str if !append_str.empty?
    fbench.ignore_first = 10
    profiler_start
    fbench.query(qf)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end

  def get_graphs()
    profiles = [ 'simple', 'rawscore', 'dotproduct', 'joinsq' ]
    casenames = [ 'alldoc', 'nns_10', 'nns_100', 'nns_1000' ]
    maxmins = {
        'alldoc_joinsq'     => { :min => 270, :max => 400 },
        'alldoc_dotproduct' => { :min => 150, :max => 250 },
        'nns_10_rawscore'   => { :min =>  10, :max => 99 },
        'default'           => { :min =>  30, :max => 80 }
    }
    local_graphs = []
    local_graphs.push({
        :x => 'legend',
        :y => '95p',
        :title => "Latency for NNS versus distance ranking",
        :filter => {'recall' => '100'},
        :historic => true
    })
    casenames.each do |casename|
      profiles.each do |profile|
        case_profile = "#{casename}_#{profile}"
        mm = maxmins[case_profile]
        mm = maxmins['default'] unless mm
        local_graphs.push({
            :x => 'legend',
            :y => '95p',
            :title => "#{case_profile}_latency",
            :y_min => mm[:min],
            :y_max => mm[:max],
            :filter => {'legend' => case_profile, 'recall' => '100'},
            :historic => true
        }) if (case_profile != 'alldoc_rawscore')
      end
    end
    return local_graphs
  end

  def teardown
    super
  end

end
