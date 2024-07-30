#!/usr/bin/env ruby
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'test_base'
require 'digest/md5'
require 'data_generator'
require 'executeerror'
require 'nodetypes/metrics'
require 'drb_endpoint'
require 'digest/md5'
require 'tls_env'
require 'environment'
require 'executor'
require 'https_client'
require 'json'
require 'resolv'
require 'remote_file_utils'

# This server is running on all Vespa nodes participating in the test.
# A NodeServer class is instantiated and made accessible to DRb. Remote
# method calls in the testcase to all the nodes running Vespa will then
# be possible.

class NodeServer
  include DRb::DRbUndumped
  include Feeder
  include QueryLoader
  include Metrics
  attr_accessor :testcase, :addr_configserver, :hostname, :port_configserver_rpc, :configserver_started
  attr_reader :tls_env
  attr_reader :https_client

  def initialize(hostname, short_hostname)
    @services = []   # must keep list of service objects created to prevent gc
    @hostname = hostname
    @short_hostname = short_hostname
    @monitoring = false
    @monitor_thread = nil
    @http_servers = {}
    @port_configserver_rpc = nil
    @configserver_pid = nil
    @configserver_started = false
    @sanitizers = nil
    @tls_env = TlsEnv.new
    @executor = Executor.new(@short_hostname)
    @https_client = HttpsClient.new(@tls_env)
  end

  def time
    Time.now
  end

  # Creates and returns an instance of a subclass of VespaNode based on the string
  # given in _service_.
  def get_service(service)
    # In case hash contains symbol keys, convert them to string keys
    # This allows the callee to use Ruby 1.9 keyword arguments
    service = symbol_to_string_keys(service) if service[:servicetype]

    case service["servicetype"]
      when "adminserver" then @services.push(Adminserver.new(service, testcase, self))
      when "configserver" then @services.push(Configserver.new(service, testcase, self))
      when "logserver" then @services.push(Logserver.new(service, testcase, self))
      when "qrserver" then @services.push(Qrserver.new(service, testcase, self))
      when "container" then @services.push(ContainerNode.new(service, testcase, self))
      when "distributor" then @services.push(Distributor.new(service, testcase, self))
      when "searchnode" then @services.push(SearchNode.new(service, testcase, self))
      when "storagenode" then @services.push(StorageNode.new(service, testcase, self))
      when "fleetcontroller" then @services.push(Fleetcontroller.new(service, testcase, self))
      when "container-clustercontroller" then @services.push(ContentClusterController.new(service, testcase, self))
      when "slobrok" then @services.push(Slobrok.new(service, testcase, self))
      when "metricsproxy-container" then @services.push(MetricsProxyNode.new(service, testcase, self))
      else return nil
    end

    return @services[@services.size - 1]
  end

  # Remove all references from the services list in order to free memory
  def cleanup_services
    @services.each do |service|
      begin
        service.cleanup
      rescue DRb::DRbConnError => e
        STDERR.puts "Failed during cleanup of service: #{e.inspect}"
      end
    end
    @services.clear
  end

  # Remove temporary file dir
  def remove_tmp_files
    FileUtils.remove_dir(@testcase.dirs.tmpdir) if File.exist?(@testcase.dirs.tmpdir)
  end

  # Sets the address of the config server in the environment
  def set_addr_configserver(config_hostnames)
    hosts = config_hostnames.map { |h| h.split(":").first }
    @addr_configserver = hosts
    Environment.instance.set_addr_configserver(@testcase, hosts)
  end

  def set_port_configserver_rpc(port=nil)
    Environment.instance.set_port_configserver_rpc(@testcase, port)
    @port_configserver_rpc = port
  end

  def reset_environment_setting
    Environment.instance.reset_environment_setting(@testcase)
  end

  def override_environment_setting(name, value)
    Environment.instance.override_environment_setting(@testcase, name, value)
  end

  def remote_eval(expr)
    eval(expr)
  end

  def alive?
    true
  end

  def shutdown
    # Just exit for now
    DRb.stop_service
  end

  # Executes _command_ in the background on this node. Returns the pid.
  def execute_bg(command)
    testcase_output("execute_bg(#{command})")
    pid = fork { exec(command) }
    pid
  end

  def kill_pid(pid, signal="TERM")
    command = "kill -#{signal} #{pid}"
    execute(command)
    waitpid(pid)
  end

  def waitpid(pid)
    Process.waitpid(pid)
  end

  # Find child pid of parent runserver
  def find_runserver_child(parent_pid)
    `ps -o pid,ppid ax | awk "{ if ( \\$2 == #{parent_pid} ) { print \\$1 }}"`.chomp
  end

  # Executes _command_ on this node. Raises an exception if the exitstatus
  # was non-zero, unless :exceptiononfailure is set to false. Echoes output
  # from the command unless :noecho.
  # Returns stdout and stderr of the command (max 100kB). If :exitcode, returns an array
  # containing exit code and stdout/stderr
  def execute(command, params={})
    @executor.execute(command, @testcase, params)
  end

  # Transfers one file from the default test data server.
  # Returns a string with local filename fetched.
  #
  def fetchfile(file)
    fetchfiles(:file => file, :testdata_url => TestBase::testdata_url(@hostname)).first
  end

  # Transfers files from either the node running the testcase using DRb, or from a spesific
  # host using network. Returns an array of local filenames fetched.
  #
  # Args:
  # * :dir - directory to fetch files from
  # * :file - specific filename to fetch
  # * :testdata_url - specify URL for test data download (NOTE: only supports :file)
  # * :destination_dir - destination directory. Defaults to test case downloaddir for remote and drbfiledir for local.
  # * :destination_file - destination file. Only allowed with :file and takes precedence over :destination_dir.
  # Note that either :dir or :file must be specified.
  def fetchfiles(params={})
    raise "ERROR: Either :dir or :file must be supplied to fetchfiles method." unless params[:file] || params[:dir]

    localfilenames = []
    if params[:testdata_url]
      raise ":dir not handled for URL #{params[:testdata_url]}" if params[:dir]

      source_url = URI("#{params[:testdata_url]}/#{params[:file]}")
      destination_dir = params[:destination_dir] ? params[:destination_dir] : @testcase.dirs.downloaddir
      localfilename = params[:destination_file] ? params[:destination_file] : File.join(destination_dir, File.basename(params[:file]))

      RemoteFileUtils.download(source_url, localfilename)

      testcase_output("Downloaded #{source_url} to #{localfilename} on host #{`hostname`}")
      localfilenames << localfilename
    else
      raise ":dir and :destination_file can not both be specified" if params[:dir] && params[:destination_file]

      destination_dir = params[:destination_dir] ? params[:destination_dir] : @testcase.dirs.drbfiledir
      destination_dir = params[:destination_file] ? File.dirname(params[:destination_file]) : destination_dir
      FileUtils.mkdir_p(destination_dir)

      filereader = @testcase.create_filereader
      if params[:dir]
        filenames = Dir.glob(params[:dir]+"/*")
      elsif params[:file]
        filenames = [params[:file]]
      end
      filenames.each do |filename|
        localfilename = params[:destination_file] ? params[:destination_file] : File.join(destination_dir, File.basename(filename))
        unless File.exist?(localfilename) && File.size?(localfilename) == filereader.size?(filename) &&
            File.mtime(localfilename) == filereader.mtime(filename) &&
            Digest::MD5.digest(localfilename) == filereader.md5(filename)
          File.open(localfilename, "w") do |fp|
            filereader.fetch(filename) do |buf|
              fp.write(buf)
            end
          end
          File.utime(Time.now, filereader.mtime(filename), localfilename)
        end
        localfilenames << localfilename
      end
    end
    localfilenames
  end

  # Copies the source file or directory on localhost to the destination directory
  # on the host this node is running. If source is a directory, copy("/foo", "/bar")
  # has the same effect as "cp -r /foo/* /bar".
  def copy(source, destination)
    filereader = @testcase.create_filereader
    FileUtils.mkdir_p(destination)
    source_name = File.basename(source)
    remotearchive = filereader.archive(source)
    filereader.openfile(remotearchive)
    localarchivename = destination + "/" + source_name + ".tar.gz"
    localarchive = File.open(localarchivename, "w")
    while block = filereader.read(4096)
      localarchive.print(block)
    end
    localarchive.close
    filereader.closefile
    execute("tar xzf #{localarchivename} --directory #{destination}")
    File.delete(localarchivename)
    filereader.delete(remotearchive)
  end

  def pid_running(pid)
    system("ps -p #{pid} &> /dev/null")
    $? == 0
  end

  # Returns an array of pids corresponding to _name_.
  def get_pids(name)
    pids = `ps awwx | grep #{name} | grep -v grep | awk '{print $1}'`
    result = []
    pids.split("\n").each do |pid|
      pid.gsub!(/\s+/, "")
      result.push(pid.to_i)
    end
    return result
  end

  # Kills the process identified by _name_. Returns a list of pids killed.
  #
  # Optional args:
  # * :pid - kill process by specifying pid instead of name
  # * :signal - signal to send to process (default is KILL)
  def kill_process(name, args={})
    signal = args[:signal] ? args[:signal] : "KILL"
    if args[:pid]
      pids = [args[:pid]]
    else
      pids = get_pids(name)
    end
    pids.each do |pid|
      command = "kill -#{signal} #{pid}"
      execute(command, :exceptiononfailure => false)
    end
    return pids
  end

  def get_unblessed_processes
    my_pid = Process.pid
    ps_output = `ps alxww`
  # testcase_output(ps_output)

    pid_ppid = {}
    pid_comm = {}
    pidlist = {}
    ps_output.each_line { |line|
      if ignore_proc(line)
        next
      end
      fields = line.split
      pid_comm[fields[2]] = fields[12..fields.size].join(" ")
      if !pid_ppid[fields[3]]
        pid_ppid[fields[3]] = []
      end
      pid_ppid[fields[3]].push(fields[2])
    }

    if pid_ppid.has_key?(my_pid.to_s)
      pid_ppid[my_pid.to_s].each { |pid|
        pidlist[pid] = pid_comm[pid]
        children = child_pids(pid, pid_ppid)
        children.each { |child|
          pidlist[child] = pid_comm[child]
        }
      }
    end
    pidlist
  end

  def ignore_proc(ps_line)
    ps_line =~ /\[perf\]|\[sh\]|\[ruby\]| perf record | free|ps alxww| PID | sh |home.y.tmp.systemtests|.*node_server.rb.*/
  end

  def child_pids(pid, pidmap)
    children = []
    if pidmap.has_key?(pid)
      children = pidmap[pid]
      children.each { |child|
        children.concat(child_pids(child, pidmap))
      }
    end
    children
  end

  def kill_unblessed_processes
    pids_to_kill = get_unblessed_processes
    if not pids_to_kill.empty?
      `kill #{pids_to_kill.keys.join(' ')}`

      # wait one second to see if everything got killed
      sleep 1

      pids_to_kill = get_unblessed_processes
      if not pids_to_kill.empty?

        # everything was not killed, wait more
        sleep 9

        # make a new list of pids to kill
        pids_to_kill = get_unblessed_processes
        if not pids_to_kill.empty?
          `kill -9 #{pids_to_kill.keys.join(' ')}`
        end
      end
    end
  end

  def is_nodeserver_child?(p, nodeserver_pid)
    process = p
    while (process.ppid != 0)
      if (process.ppid == nodeserver_pid)
        return true
      end
      process = ProcTable.ps(process.ppid)
    end
    false
  end

  def reset_logctl
    command = "rm -f #{Environment.instance.vespa_home}/var/db/vespa/logcontrol/*"
    execute(command, :exceptiononfailure => false)
  end

  # Finds coredumps on this node that happened between _starttime_ and _endtime_.
  # Copies the coredumps and binaryfiles that created the dumps for later inspection.
  # Returns an array of VespaCoredump objects.
  def check_coredumps(starttime, endtime)
    coredumps = []
    binaries = {}
    coredir = "#{Environment.instance.vespa_home}/var/crash/"
    bindir = "#{Environment.instance.vespa_home}/bin/"
    sbindir = "#{Environment.instance.vespa_home}/sbin/"
    ignored_files = ['.', '..', 'systemtests'].to_set
    ignored_binaries = ['perf'].to_set
    if File.directory?(coredir)
      Dir.foreach(coredir) do |filename|
        next if ignored_files.include?(filename)
        # subtract 1 second to avoid crashtime > endtime, as file system resolution is low
        crashtime = Time.at(File.mtime(coredir+filename) - 1)
        testcase.output("possible coredump: #{filename}, crashtime=#{crashtime.to_f}, starttime=#{starttime.to_f}, endtime=#{endtime.to_f}")
        if crashtime.to_i >= starttime.to_i and crashtime <= endtime
          FileUtils.chmod 0444, (coredir+filename)

          if filename =~ /(\S+)\..*core/
            binaryname = $1
            if binaryname =~ /^memcheck-amd64.*/
              binaryname = "#{Environment.instance.vespa_home}/lib64/valgrind/memcheck-amd64-linux"
            end

            if ! ignored_binaries.include?(binaryname)
              binaries[binaryname] = true
              FileUtils.mkdir_p(@testcase.dirs.coredir)
              FileUtils.mv(coredir+filename, @testcase.dirs.coredir)
              coredumps << VespaCoredump.new(@testcase.dirs.coredir, filename, binaryname)
            end
          elsif filename =~ /^hs_err_pid\d+\.log$/
            binaryname = 'java'
            FileUtils.mkdir_p(@testcase.dirs.coredir)
            FileUtils.mv(coredir+filename, @testcase.dirs.coredir)
            coredumps << VespaCoredump.new(@testcase.dirs.coredir, filename, binaryname)
          end
        end
      end
      binaries.each_key do |binary|
        if File.exist?(bindir+binary)
          FileUtils.cp(bindir+binary, @testcase.dirs.coredir)
        elsif File.exist?(sbindir+binary)
          FileUtils.cp(sbindir+binary, @testcase.dirs.coredir)
        end
      end
    end
    coredumps
  end

  def find_coredumps(starttime, exact_filename = nil)
    cores = []
    coredir = "#{Environment.instance.vespa_home}/var/crash/"
    if File.directory?(coredir)
      Dir.foreach(coredir) do |filename|
        next if filename == '.' || filename == '..'
        next if filename == 'systemtests'
        next if (exact_filename && exact_filename != filename)
        crashtime = File.mtime(coredir+filename)
        if crashtime.to_i >= starttime.to_i
          cores << coredir+filename
        end
      end
    end
    cores
  end

  def drop_coredumps(starttime)
    coredumps = find_coredumps(starttime)
    coredumps.each do |coredump|
      File.unlink(coredump)
    end
    coredumps.size
  end

  def get_stateline(path)
    f = File.open(path, "r")
    lines = f.readlines
    f.close()
    line = lines[0]
    line = line.chop
    line
  end

  def available_space
    # returns amount of free space on build partition
    df_out = `df -kP /home | tail -n 1`
    df_out.split[3].to_i
  end

  def cleanup_coredumps(wanted_free_space)
    removed_dirs = []
    File.open("/tmp/coredump_cleanup.log", "w") do |f|
      f.puts("Listing files...")
      files = Dir["#{Environment.instance.vespa_home}/var/crash/systemtests/*/*"]
      files.sort! { | a, b | File.new(b).stat <=> File.new(a).stat } # by creation time reverse
      f.puts("Got files: #{files.inspect}")
      while (wanted_free_space > available_space() && !files.empty?)
        target = files.pop
        f.puts("Trying to remove: #{target}")
        # only remove coredump dirs if they are older than 4 days
        if (File.stat(target).mtime < (Time.now - 4*24*3600))
          FileUtils.rm_rf(target)
          removed_dirs << target
          f.puts("Tried to remove")
        else
          f.puts("Not removing, too new")
        end
      end
      f.puts("All done")
    end
    removed_dirs
  end

  def wait_until_file_exists(filename, timeout)
    timeout.times {
      if File.exist?(filename)
        return true
      end

      sleep 1
    }

    return false
  end

  # Writes _type_ operations to generated document IDs _prefix[0, ..._count_], with other fields as given by _operation_ to _filename_.
  # Example:
  # write_document_operations(:update,
  #                           { :condition => 'title="empty"', :fields => { :title => { :assign => 'unknown' } } },
  #                           'id:ns:doctype::',
  #                           1 << 20,
  #                           '1M_ops.json')
  def write_document_operations(type, operation, prefix, count, filename, array = true)
    FileUtils.mkdir_p(File.dirname(filename))
    File.open(filename, "w") do |file|
      if array
        file.puts('[')
      end
      count.times { |i| file.puts(operation.merge({type => (prefix + i.to_s)}).to_json + (i + 1 < count ? "," : "")) }
      if array
        file.puts(']')
      end
    end
  end

  # Writes templated queries into filename, count times.
  def write_queries(template:, yql: false, count: nil, parameters: {}, data: nil, filename:)
    FileUtils.mkdir_p(File.dirname(filename))
    command = DataGenerator.new.query_command(template: template, yql: yql, count: count, parameters: parameters, data: data)
    execute("#{command} > #{filename}")
  end

  # Writes templated urls into filename, count times.
  def write_urls(template:, path:, count: nil, parameters: {}, data: nil, filename:)
    FileUtils.mkdir_p(File.dirname(filename))
    command = DataGenerator.new.url_command(template: template, path: path, count: count, parameters: parameters, data: data)
    execute("#{command} > #{filename}")
  end

  # Writes _content_ into _filename_.
  def writefile(content, filename)
    FileUtils.mkdir_p(File.dirname(filename))
    File.open(filename, "w") do |file|
      file.print(content)
    end
  end

  # Returns the content of _filename_.
  def readfile(filename)
    if File.exist?(filename)
      File.open(filename) do |file|
        while buf = file.read(1024*4096)
          yield buf
        end
      end
      true
    else
      nil
    end
  end

  # Removes _filename_.
  def removefile(filename)
    if File.exist?(filename)
      File.delete(filename)
    end
  end

  # Lists files found with the glob _expression_.
  def list_files(expression)
    Dir.glob(expression)
  end

  # Returns the absolute and resolved path of the symlink _filename_.
  def resolve_symlink(filename)
    if File.symlink?(filename)
      File.realpath(filename)
    else
      nil
    end
  end

  # Sets the bash environment variable _name_ to _value_.
  def set_bash_variable(name, value)
    ENV[name] = value
  end

  # Unsets the bash environment variable _name_.
  def unset_bash_variable(name)
    ENV[name] = ""
  end

  def maven_compile(sourcedir, bundle, haspom, vespa_version)
    mvnargs = ''
    mvnargs += bundle.params[:mavenargs] if bundle.params[:mavenargs]
    execute("cd #{sourcedir}; #{@testcase.maven_command} install #{mvnargs}")

    jarfile = sourcedir + "/target/" + File.basename(sourcedir) + ".jar"
    if !(haspom && File.exist?(jarfile))
      jarfile = sourcedir + "/target/" + bundle.generate_final_name + ".jar"
    end
    bundle = File.open(jarfile)
    data = bundle.read()
    data
  end

  def maven_install_parent(src)
    copy(File.join(src, "pom.xml"), "#{Environment.instance.tmp_dir}/parent.pom.xml")
    execute("cd #{Environment.instance.tmp_dir}; #{@testcase.maven_command} install -N -f parent.pom.xml")
  end

  # Returns a hashtable of file status information for all files residing in
  # path, recursively. Also provided is a selector function which selects which
  # field to store.
  def stat_files(path, selector)
    status = Hash.new
    filelist = Dir.glob(path)
    filelist.each { |filename|
      stat = File.stat(filename)
      status[filename] = selector.call(stat)
    }
    return status
  end

  # Compiles java source code in _sourcedir_, storing the result in _destdir_ using
  # the given _classpath_.
  def compile_java(classpath, destdir, sourcedir, makejar=false)
    buildfile = sourcedir+"/build.xml"
    generate_build_script(classpath, destdir, sourcedir, buildfile, makejar)
    execute("ANT_OPTS=-Xmx512m cd #{sourcedir}; ant")
  end

  # Compiles the C++ source code in _sourcedir_, storing the result in _destdir_.
  def compile_cpp(destdir, sourcedir, target=nil)
    makecmd = "make"
    if target != nil then
      makecmd += " #{target}"
    end
    execute("cd #{sourcedir}; #{makecmd}")
  end

  # Deletes class and JAR files based on source code in _sourcedir_
  def delete_java(destdir, sourcedir)
    buildfile = sourcedir+"/delete.xml"
    generate_delete_script(destdir, sourcedir, buildfile)
    execute("ANT_OPTS=-Xmx512m cd #{sourcedir}; ant -buildfile #{buildfile}")
  end

  # Generates an ant build script with name _buildfile_ for java compiling.
  def generate_build_script(classpath, destdir, srcdir, buildfile, makejar=false)

    classfiles = []
    Dir.glob(srcdir).each do |filename|
      if (filename =~ /.+\.java/)
        classfiles << File.basename(filename).sub(/\.java/, ".class")
      end
    end

    jarfile = ""
    Dir.glob(srcdir).each do |filename|
      if (filename =~ /.+\.java/)
        jarfile = jarfile + File.basename(filename).sub(/\.java/, "")
      end
    end
    jarfile = jarfile + ".jar"

    file = File.open(buildfile, "w")
    file.write("<?xml version=\"1.0\"?>\n")
    file.write("<project name=\"javadev\" default=\"compile\" basedir=\".\">\n")
    file.write("  <target name=\"init\">\n")
    file.write("    <mkdir dir=\"#{destdir}\"/>\n")
    classfiles.each do |classfile|
      file.write("    <delete file=\"#{destdir}/#{classfile}\"/>\n")
    end
    file.write("    <delete file=\"#{destdir}/#{jarfile}\"/>\n")
    file.write("  </target>\n")
    file.write("  <target name=\"compile\" depends=\"init\">\n")
    file.write("    <javac debug=\"true\" srcdir=\"#{srcdir}\" destdir=\"#{destdir}\" classpath=\"#{classpath}\"/>\n")
    if (makejar)
      #make JAR file
      file.write("    <jar jarfile=\"#{destdir}/#{jarfile}\" duplicate=\"preserve\">\n")
      file.write("      <fileset dir=\"#{destdir}\" includes=\"")
      #include class files in JAR
      classfiles.each do |classfile|
        file.write("#{classfile} ")
      end
      file.write("\"/>\n")
      file.write("    </jar>\n")
      #delete class files
      classfiles.each do |classfile|
        file.write("    <delete file=\"#{destdir}/#{classfile}\"/>\n")
      end
    end
    file.write("  </target>\n")
    file.write("</project>\n")
    file.close()
  end

  # Generates an ant build script with name _buildfile_ for java deleting
  def generate_delete_script(destdir, srcdir, buildfile)

    classfiles = []
    Dir.glob(srcdir).each do |filename|
      if (filename =~ /.+\.java/)
        classfiles << File.basename(filename).sub(/\.java/, ".class")
      end
    end

    jarfile = ""
    Dir.glob(srcdir).each do |filename|
      if (filename =~ /.+\.java/)
        jarfile = jarfile + File.basename(filename).sub(/\.java/, "")
      end
    end
    jarfile = jarfile + ".jar"

    file = File.open(buildfile, "w")
    file.write("<?xml version=\"1.0\"?>\n")
    file.write("<project name=\"javadev\" default=\"delete\" basedir=\".\">\n")

    file.write("  <target name=\"delete\">\n")
    file.write("    <mkdir dir=\"#{destdir}\"/>\n")
    classfiles.each do |classfile|
      file.write("    <delete file=\"#{destdir}/#{classfile}\"/>\n")
    end
    file.write("    <delete file=\"#{destdir}/#{jarfile}\"/>\n")
    file.write("  </target>\n")
    file.write("</project>\n")
    file.close()
  end

  # Starts vespa_base on the node
  def start_base
    cmd = Environment.instance.additional_start_base_commands
    cmd += "#{Environment.instance.vespa_home}/bin/vespa-start-services"
    execute(cmd)
  end

  # Stops vespa_base on the node.
  def stop_base
    execute("#{Environment.instance.vespa_home}/bin/vespa-stop-services")
  end

  def ping_configserver(timeout=300)
    start = Time.now.to_i
    if (!@port_configserver_rpc)
      cmd = 'vespa-print-default configserver_rpc_port'
      @port_configserver_rpc = execute(cmd, :exceptiononfailure => false, :noecho => true).chomp.to_i
    end
    # TODO: Make configurable
    port_configserver_http = 19071
    spec = "#{@hostname}:#{@port_configserver_rpc}"

    rpc_port_up = false
    http_port_up = false
    begin
      configserver(@hostname, @port_configserver_rpc).ping() unless rpc_port_up
      rpc_port_up = true
      configserver_http_ping(@hostname, port_configserver_http) unless http_port_up
      http_port_up = true
    rescue StandardError => se
      if (Time.now.to_i - start > 20)
        testcase_output("Config server on #{spec} failed: #{se}")
      end
      sleep 0.1
      if Time.now.to_i - start > 200
        execute("vespa-logfmt -l all | tail -n 300", :exceptiononfailure => false)
        execute("vespa-logfmt -l all #{Environment.instance.vespa_home}/logs/vespa/zookeeper.configserver.0.log | tail -n 1000", :exceptiononfailure => false)
        execute("ps xgauww | grep 'config[s]erver'", :exceptiononfailure => false)
        execute("netstat -an | grep #{@port_configserver_rpc}", :exceptiononfailure => false)
      end
      if Time.now.to_i - start < timeout
        retry
      else
        testcase_output("Failed connecting to config server on #{spec}. Gave up after #{timeout} seconds.")
        execute("ls -latr #{Environment.instance.vespa_home}/var/zookeeper", :exceptiononfailure => false)
        execute("ls -latr #{Environment.instance.vespa_home}/var/zookeeper/version-2", :exceptiononfailure => false)
        print_configserver_stack
        raise
      end
    end
    testcase_output("Config server on #{hostname} is alive")
  end

  def start_configserver
    if @configserver_started then
      # Optimization: Don't start unless it's necessary
      # Ping configserver to be sure that our assumption is correct
      begin
        ping_configserver(10)
        return
      rescue StandardError => se
        testcase_output("Config server state: running, but not responding to ping, so starting it anyway")
      end
    end
    cwd = `/bin/pwd`
    Environment.instance.start_configserver(@testcase)
    Dir.chdir(cwd) if cwd == "/var/builds/"
    configserver_runserver_pid = execute("ps auxww | grep \"configserver.pid\" | grep -v grep | tr -s ' ' | cut -f 2 -d ' ' | tail -n 1", :noecho => true).to_i
    @configserver_pid = execute("pgrep -P #{configserver_runserver_pid} | tail -n 1", :noecho => true).to_i
    testcase_output("Configserver running with pid #{@configserver_pid}")
    @configserver_started = true
  end

  def get_configserver_pid
    @configserver_pid
  end

  def stop_configserver(params={})
    Environment.instance.stop_configserver(@testcase)
    @configserver_started = false
    if params[:keep_everything] then
      return
    end

    # Delete aplication packages
    FileUtils.rm_rf Dir.glob("#{Environment.instance.vespa_home}/var/db/vespa/config_server/serverdb/tenants/*") unless params[:keep_configserver_data]

    # Delete all files in hosted-vespa dir
    FileUtils.rm_rf Dir.glob("#{Environment.instance.vespa_home}/conf/configserver-app/hosted-vespa/*")

    # reset zookeeper between runs
    FileUtils.rm_rf Dir.glob("#{Environment.instance.vespa_home}/var/zookeeper/*") unless params[:keep_zookeeper_data]

    # Delete file distribution directory
    FileUtils.rm_rf("#{Environment.instance.vespa_home}/var/db/vespa/filedistribution") unless params[:keep_filedistribution_data]

    # Copy all interesting files into testcase directory to be able to inspect.
    FileUtils.mkdir_p(@testcase.dirs.vespalogdir)
    files_to_copy = []
    files_to_copy.concat(Dir.glob("#{Environment.instance.vespa_home}/logs/vespa/vespa.log*"))
    files_to_copy.concat(Dir.glob("#{Environment.instance.vespa_home}/logs/vespa/configserver/access.log.*"))
    files_to_copy.concat(Dir.glob("#{Environment.instance.vespa_home}/logs/vespa/zookeeper.*.log*"))
    files_to_copy.each do |file|
      FileUtils.cp(file, File.join(@testcase.dirs.vespalogdir, "#{@short_hostname}_#{File.basename(file)}")) unless File.stat(file).size == 0
    end
  end

  # Removes vespa indexes on the node.
  def clean_indexes
    execute("vespa-remove-index -force", :exceptiononfailure => false)
  end

  # Output _str_ to node running testcase.
  def testcase_output(str, newline=true)
    @testcase.output(str, newline) if @testcase
  end

  def print_configserver_stack
    execute("top -b -n 1", :exceptiononfailure => false)
    execute("ps -p #{@configserver_pid} && /usr/bin/sudo -u #{Environment.instance.vespa_user} jstack #{@configserver_pid}", :exceptiononfailure => false)
  end

  # Start monitoring of memory in new thread
  def start_monitoring
    @monitoring = true
    @monitor_thread = Thread.new do
      max_memory = 0
      count = 0
      while @monitoring
        sleep 0.1
        if count % 10 == 0
            used_memory = `free -b | grep + | awk {'print $3'}`.strip.to_i
            if used_memory > max_memory
              max_memory = used_memory
            end
        end
        count += 1
      end
      max_memory
    end
  end

  def stop_monitoring
    @monitoring = false
    if @monitor_thread
      mem = @monitor_thread.value
      @monitor_thread = nil
      mem
    end
  end

  def file_exist?(path)
    File.exist?(path)
  end

  def file?(path)
    File.file?(path)
  end

  def directory?(path)
    File.directory?(path)
  end

  def get_current_time_as_int
    Time.now.to_i
  end

  def create_unique_temp_file(template)
    tmp = Tempfile.new(template)
    path = tmp.path
    tmp.close!()
    return path
  end

  def create_tmp_bin_dir
    dir = "#{Environment.instance.vespa_home}/tmp/systemtests-bin"
    FileUtils.mkdir_p(dir)
    return dir
  end

  def detect_sanitizers
    @sanitizers = execute("#{Environment.instance.vespa_home}/bin/vespa-print-default sanitizers", :noecho => true).chomp.split(',').sort
  end

  def setup_sanitizers
    dir = "#{Environment.instance.tmp_dir}/sanitizer"
    FileUtils.mkdir_p(dir)
    FileUtils.chown(Environment.instance.vespa_user, nil, dir)
    detect_sanitizers if @sanitizers.nil?
    @sanitizers.each do |name|
      if name == 'address'
        ENV['ASAN_OPTIONS'] = "log_path=#{dir}/asan-log"
      elsif name == 'thread'
        ENV['TSAN_OPTIONS'] = "suppressions=#{Environment.instance.vespa_home}/etc/vespa/tsan-suppressions.txt history_size=7 detect_deadlocks=1 second_deadlock_stack=1 log_path=#{dir}/tsan-log"
      elsif name == 'undefined'
        ENV['UBSAN_OPTIONS'] = "print_stacktrace=1:log_path=#{dir}/ubsan-log"
      end
    end
  end

  def reset_sanitizers(cleanup)
    dir = "#{Environment.instance.tmp_dir}/sanitizer"
    FileUtils.rm_rf(dir) if cleanup
    ENV['ASAN_OPTIONS'] = nil
    ENV['TSAN_OPTIONS'] = nil
    ENV['UBSAN_OPTIONS'] = nil
  end

  # Not safe to call - part of remote copy methods in node_proxy.rb
  def private_copy_archive_to_node_and_extract(source, dst_dir, orig_name, rename_to)
    # Copy remote archive to local (node) archive
    local_tarfile = Tempfile.new("systemtest_copy_")
    filereader = @testcase.create_filereader
    filereader.openfile(source)
    while block = filereader.read(4096)
      s = local_tarfile.write(block)
    end
    local_tarfile.close()

    # Extract files locally
    FileUtils.mkdir_p(dst_dir)
    cmd = "cd #{dst_dir} && tar xzf #{local_tarfile.path}"
    execute(cmd)

    # Remove temporary archives
    local_tarfile.close!();
  end

  private
  def configserver(hostname, port)
    @rpc_to_cfgs or @rpc_to_cfgs = RpcWrapper.new(hostname, port, @tls_env)
  end

  private
  def configserver_http_ping(hostname, port)
    response = https_client.get(hostname, port, '/state/v1/health')
    raise StandardError.new("Got response code #{response.code}") unless response.is_a?(Net::HTTPSuccess)
    json = JSON.parse(response.body)
    status = json["status"]["code"]
    if status != 'up'
      raise StandardError.new("Got status #{status}")
    end
  end
end

def symbol_to_string_keys(hsh)
  hsh.map { |k,v| [k.to_s, v] }.to_h
end

def toggle_config_sentinel_no_new_privs_process_bit
  # Applies to all processes launched by the config sentinel.
  # See https://www.kernel.org/doc/Documentation/prctl/no_new_privs.txt
  ENV['VESPA_PR_SET_NO_NEW_PRIVS'] = 'true'
end

def main(callback_endpoint)
  # Instantiates a NodeServer object and publishes it through DRb.
  hostname = Environment.instance.vespa_hostname
  short_hostname = Environment.instance.vespa_short_hostname
  ENV['PATH'] = "#{Environment.instance.path_env_variable}:#{ENV['PATH']}"
  toggle_config_sentinel_no_new_privs_process_bit

  if callback_endpoint
    # This can be specified with :0 to pick an available port, but use the fixed port for now
    service_endpoint = "#{hostname}:#{TestBase::DRUBY_REMOTE_PORT}"

    # This has to be created before the node_server_endpoint so that endpoint becomes the primary server
    node_controller_endpoint = DrbEndpoint.new(callback_endpoint)
    node_controller_client = node_controller_endpoint.create_client(with_object: nil)
  else
    service_endpoint = "#{hostname}:#{TestBase::DRUBY_REMOTE_PORT}"
  end

  Environment.instance.backup_environment_setting(false)

  front_object = NodeServer.new(hostname, short_hostname)

  node_server_endpoint = DrbEndpoint.new(service_endpoint)

  while true
    node_server_endpoint.start_service(for_object: front_object)

    node_server_uri = URI.parse(DRb.current_server.uri)

    puts("Node server endpoint: #{node_server_uri.host}:#{node_server_uri.port} " +
             "(#{node_server_endpoint.secure? ? 'secure' : 'INSECURE'})")

    if callback_endpoint
      node_controller_client.register_node_server(node_server_uri.host, node_server_uri.port, ENV['PARENT_NODE_NAME'])
      puts("Registered node server at #{callback_endpoint}")
    end

    begin
      node_server_endpoint.join_service_thread
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Errno::EPIPE, Errno::EINVAL, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
      puts("Node server got an exception: " + e.message)
    end

    if callback_endpoint
      # When using the callback to register, we will exit after finishing
      break
    end
  end
end

if __FILE__ == $0
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6.0') && !( RUBY_PLATFORM =~ /darwin/ )
    # Ruby version >= 2.6.0 disables transparent hugepages for the process. This has negative effects
    # for forked processes and leads to a high number of interrupts (at least for the vespa-feed-perf client).
    # We fix this here by enabling the THP here before doing anything else.
    require 'process_ctrl'
    ProcessCtrl.set_thp_disable(0)
  end

  callback_endpoint = nil
  callback_endpoint = nil
  generate_tls_env_and_exit = false

  o = OptionParser.new
  o.on("-c", "--callbback HOST:PORT", String, "Host and port to use for registering this nodeserver", String) {|v| callback_endpoint = v}
  o.on("-g", "--generate-tls-env-and-exit", "Only generate TLS environment files and exit.") {|v| generate_tls_env_and_exit = v}
  begin
    o.parse!(ARGV)
  rescue OptionParser::InvalidOption
    puts o.to_s
    exit 1
  end

  if generate_tls_env_and_exit
    ENV.delete(TlsEnv::CONFIG_FILE_ENV_VAR)
    TlsEnv.new
    exit 0
  end

  main(callback_endpoint)
end
