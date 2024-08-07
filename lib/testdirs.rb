# Copyright Vespa.ai. All rights reserved.
require 'fileutils'
require 'drb'

class TestDirs
  include DRb::DRbUndumped

  attr_reader :benchmarklogdir, :vespalogdir, :valgrindlogdir, :testoutput, :filesdir
  attr_reader :benchmarklogdir_web, :vespalogdir_web, :valgrindlogdir_web, :testoutput_web, :filesdir_web
  attr_reader :tmpdir, :rrdsdir, :graphdir, :coredir, :downloaddir, :drbfiledir
  attr_reader :bundledir, :resultoutput, :plugindir, :baselogdir
  attr_reader :jdisccorelogdir
  attr_reader :sanitizerlogdir

  def initialize(testclass, testmethod, modulename, args={})
    methodname = testmethod.sub(/test_/, "")
    start_timestamp = args[:start_timestamp]
    outputdir = args[:outputdir]
    platform_label = args[:platform_label]
    buildversion = args[:buildversion]
    buildname = args[:buildname]

    # example of test date format: 2006-04-20T23-44-28
    starttime_string = start_timestamp.strftime("%Y-%m-%dT%H-%M-%S") if start_timestamp
    pid = Process.pid

    bigbasedir = Environment.instance.vespa_home
    if args[:basedir]
      basedir = args[:basedir]
    else
      basedir = bigbasedir
    end

    if outputdir
      baselogdir = outputdir
      logdir = outputdir
      dbdir = outputdir
      logdir_web = ""
    elsif platform_label and buildversion and buildname # i.e web
      baselogdir = "#{basedir}/logs/systemtests/#{platform_label}/#{buildversion}/#{buildname}"
      logdir = "#{baselogdir}/#{modulename}"
      logdir_web = "systemtestlogs/#{platform_label}/#{buildversion}/#{buildname}/#{modulename}"
      dbdir = "#{basedir}/var/db/systemtests/#{platform_label}/#{buildversion}/#{buildname}/#{modulename}"
    else
      baselogdir = "#{basedir}/logs/systemtests"
      logdir = baselogdir;
      logdir_web = ""
      dbdir = "#{basedir}/var/db/systemtests/#{modulename}"
    end

    @downloaddir = "#{bigbasedir}/tmp/systemtests/transferred_files/"
    @drbfiledir = "#{bigbasedir}/tmp/systemtests/transferred_files_drb/"
    @tmpdir = "#{basedir}/tmp/systemtests/#{testclass}/#{methodname}/#{starttime_string}/pid.#{pid}/"
    @bundledir = "#{@tmpdir}/bundles/"
    @coredir = "#{basedir}/var/crash/systemtests/#{methodname}/#{starttime_string}/"

    @testoutput = "#{logdir}/#{testclass}/#{methodname}/testoutput.log"
    @testoutput_web = "systemtestlogs/#{platform_label}/#{buildversion}/#{buildname}/#{modulename}/#{testclass}/#{methodname}/testoutput.log"
    @valgrindlogdir = "#{logdir}/#{testclass}/#{methodname}/valgrind/"
    @valgrindlogdir_web = "systemtestlogs/#{platform_label}/#{buildversion}/#{buildname}/#{modulename}/#{testclass}/#{methodname}/valgrind/"
    @benchmarklogdir = "#{logdir}/#{testclass}/#{methodname}/benchmark/"
    @benchmarklogdir_web = "systemtestlogs/#{platform_label}/#{buildversion}/#{buildname}/#{modulename}/#{testclass}/#{methodname}/benchmark/"
    @vespalogdir = "#{logdir}/#{testclass}/#{methodname}/vespalog/"
    @vespalogdir_web = "systemtestlogs/#{platform_label}/#{buildversion}/#{buildname}/#{modulename}/#{testclass}/#{methodname}/vespalog/"
    @baselogdir = baselogdir
    @jdisccorelogdir = "#{logdir}/#{testclass}/#{methodname}/jdisc/"
    @sanitizerlogdir = "#{logdir}/#{testclass}/#{methodname}/sanitizer/"

    @filesdir = "#{logdir}/#{testclass}/#{methodname}/files/"
    @filesdir_web = "systemtestlogs/#{platform_label}/#{buildversion}/#{buildname}/#{modulename}/#{testclass}/#{methodname}/files/"

    @rrdsdir = "#{dbdir}/#{testclass}/#{methodname}/rrds/"
    @graphdir = "#{dbdir}/#{testclass}/#{methodname}/graphs/"
    @resultoutput = "#{logdir}/#{testclass}/#{methodname}/results/"
    @plugindir = "#{logdir}/#{testclass}/#{methodname}/plugins/"

    @create_dirlist = [@vespalogdir, @benchmarklogdir, @tmpdir,
                       @valgrindlogdir, @rrdsdir, @graphdir, @bundledir,
                       @resultoutput, @filesdir, @plugindir, @jdisccorelogdir,
                       @sanitizerlogdir]
  end

  def create_directories
    @create_dirlist.each do |dir|
      begin
        FileUtils.mkdir_p(dir)
      rescue Errno::EACCES
        raise "Unable to create #{dir}, make sure you have the correct permissions"
      end
    end
  end

  def remove_directories(debug=false)
    @create_dirlist.each do |dir|
      if File.exist?(dir)
      	FileUtils.rm_rf(dir)
      end
    end
    FileUtils.rm(@testoutput)
  end
end
