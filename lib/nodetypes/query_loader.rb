# Copyright Vespa.ai. All rights reserved.

module QueryLoader

  def run_fbench(queryfile, params={})
    results = []
    clients = params[:clients] ? params[:clients] : 10
    qrserver = params[:qrserver] ? params[:qrserver] : testcase.vespa.container.values.first
    if params[:cycletime]
      cycletime = params[:cycletime]
    elsif params[:qps]
      cycletime = find_cycle_time(clients, params[:qps]).to_s
    else
      cycletime = "-1"
    end

    # split query file
    querypattern = splitfiles(queryfile, clients, pattern="query%03d.txt")

    fbenchcmd = "vespa-fbench -n #{clients} -q #{querypattern} "
    fbenchcmd += "-c #{cycletime} "
    fbenchcmd += "-s #{params[:seconds]} " if params[:seconds]
    fbenchcmd += "-r #{params[:reuse]} " if params[:reuse]
    fbenchcmd += "-o #{params[:output]} " if params[:output]
    fbenchcmd += "-xy " if params[:get_extended]
    fbenchcmd += "-D " unless params[:disable_tls]
    fbenchcmd += "-i 1 " unless params[:include_handshake]
    fbenchcmd += "#{qrserver.name} #{qrserver.http_port} "
    qrserver2 = params[:qrserver2]
    fbenchcmd += "#{qrserver2.name} #{qrserver2.http_port}" if params[:multiple_qrs]
    fbenchoutput = execute(fbenchcmd)
    fbenchlog = testcase.dirs.benchmarklogdir+File.basename(queryfile)+".log"
    qrserver.writefile(fbenchoutput, fbenchlog)
    testcase.output("Finished running vespa-fbench #{File.basename(queryfile)} on #{qrserver.name}.")
    parse_fbench(fbenchoutput)
  end

  def run_multiple_fbenches(queryfilepattern, iteration, params={})
    #queryfilepattern must be an array of paths with patterns:
    #pub/verticals/docs/queries_100_rounds/query%02d0.txt
    #patterns for generation patterns seems a bit tricky

    results = []
    seconds = params[:seconds] ? params[:seconds] : 60
    qps = params[:qps] ? params[:qps] : nil
    if params[:qrservers] and params[:qrservers] < queryfilepattern.size
      qrservers = params[:qrservers]
    else
      qrservers = queryfilepattern.size
    end
    if qrservers > 1
      threads = []
      (0..qrservers).each do |qrs|
        threads << Thread.new(qrs) do |my_qrs|
          results.push(self.run_fbench(queryfilepattern[my_qrs] % iteration, :clients => 100, :qps => qps, :seconds => seconds, :qrserver => vespa.qrserver[my_qrs.to_s]))
        end
      end
    else
      results.push(self.run_fbench(queryfilepattern[0] % iteration, :clients => 100, :qps => qps, :seconds => seconds))
    end
    results
  end

  def find_cycle_time(clients, qps)
    1000 * clients / qps
  end

  def parse_fbench(fbenchoutput)
    result = {}
    if fbenchoutput =~ /failed requests:\s+(\d+)/
      result[:failed] = $1.to_i
    end
    if fbenchoutput =~ /successful requests:\s+(\d+)/
      result[:success] = $1.to_i
    end
    if fbenchoutput =~ /95 percentile:\s+(\d+\.\d+)/
      result[:percentile_95] = $1.to_i
    end
    if fbenchoutput =~ /99 percentile:\s+(\d+\.\d+)/
      result[:percentile_99] = $1.to_i
    end
    if fbenchoutput =~ /actual query rate:\s+(\d+\.\d+)/
      result[:qps] = $1.to_f
    end
    if fbenchoutput =~ /zero hit queries:\s+(\d+\.\d+)/
      result[:zerohit] = $1.to_f
    end
    result
  end

  def runqueries(queryfiles, hours, qps, qrservers)
    @clients = 100
    @roundtime = 900  # 15 minutes
    @unique_query_rounds = 16  # 15 mins * 16 = 4 hours of queries

    @queryfile = concatenate_queries(queryfiles)
    @qrsfiles = splitfiles(@queryfile, qrservers.length, "qrs%02d")
    @threads = []
    @i = 0

    qrservers.each do |qrserver|
      @threads << Thread.new(qrserver) do |my_qrserver|
        queryfile = @qrsfiles[@i]
        roundfiles = splitfiles(queryfile, @unique_query_rounds, "round%02d")
        @unique_query_rounds.times do |round|
          splitfiles(roundfiles[round], @clients, "client%03d")
        end
        rounds = (hours * 3600 / @roundtime).ceil
        rounds.times do |round|
          queryround = round % @unique_query_rounds
          querydir = File.dirname(roundfiles[queryround])
          querypattern = querydir+"/client%03d/allqueries"
          qps_per_qrs = qps / qrservers.length
          fbench(querypattern, qps_per_qrs, my_qrserver, round)

          # need to commit_samples in sampler
        end
        @i = @i + 1
      end
    end
    return @threads
  end

  def concatenate_queries(queryfiles)
    local_queryfiles = fetchfiles(queryfiles)
    date_string = Time.new.strftime("%Y-%m-%dT%H-%M-%S")
    tmpdir = File.dirname(local_queryfiles.first)
    allqueries = tmpdir+"/queries-#{date_string}/allqueries"
    FileUtils.mkdir_p(File.dirname(allqueries))
    File.open(allqueries, "w") do |destination|
      local_queryfiles.each do |queryfile|
        File.open(queryfile, "r") do |source|
          while block = source.read(4096)
            destination.print(block)
          end
        end
      end
    end
    return allqueries
  end

  def localfilename(filename)
    local_file = fetchfiles(filename).first
    return local_file
  end

  def splitfiles(queryfile, clients=100, pattern="query%03d.txt")
    local_queryfile = fetchfiles(:file => queryfile).first
    dirname = File.dirname(local_queryfile)+"/#{File.basename(local_queryfile)}_#{clients}splits"
    FileUtils.mkdir_p(dirname)
    splitpattern = "#{dirname}/#{pattern}"
    splitcmd = "vespa-fbench-split-file -p '#{splitpattern}' #{clients} #{local_queryfile}"
    execute(splitcmd)
    splitpattern
  end

end
