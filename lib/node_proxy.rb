# Copyright Vespa.ai. All rights reserved.

require 'tempfile'
require 'drb_endpoint'
require 'node_server_interface'

# This class is the local reference to the remote NodeServer object.
# Each node in hosts.xml is represented by an object of this class.
# When methods are called in this object, they are forwarded to
# the remote NodeServer object using ruby rpc calls (DRb).

class NodeClient
  include DRb::DRbUndumped

  def initialize(hostname, testcase)
    @name = hostname
    @node_server = create_node_server
    @node_server.testcase = testcase
  end

  ERRORS_TO_RETRY = [
    Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Errno::EPIPE, Errno::EINVAL, Errno::ECONNRESET, Errno::EHOSTUNREACH
  ]

  def method_missing(...)
    retries = 0
    max_retries = 3
    begin
      @node_server.send(...)
    rescue *ERRORS_TO_RETRY => e
      if retries < max_retries
        sleep retries
        retry
      else
        raise e
      end
    end
  end

  private

  def create_node_server
    remote = @name.include?(":") ? @name : "#{@name}:#{TestBase::DRUBY_REMOTE_PORT}"
    endpoint = DrbEndpoint.new(remote)
    endpoint.create_client(with_object: nil)
  end
end

class NodeProxy
  include DRb::DRbUndumped
  include NodeServerInterface

  # the hostname of the remote machine
  attr_reader :name

  # Creates a new NodeProxy object and connects to _hostname_
  # via DRb. A reference to the originating _testcase_ is passed to
  # the remote NodeServer object.
  def initialize(hostname, testcase)
    @name = hostname
    # When running system tests on docker swarm using the provided
    # run-tests-on-swarm.sh script, the first component of the host
    # name is service name and the second component is task slot.  Use
    # both to ensure unique short names for a multinode test on swarm.
    hostname_components = hostname.split(".")
    if hostname_components.size > 0
      if hostname_components.size > 1 && hostname_components[1] =~ /^\d+$/
        @short_name = hostname_components.first(2).join(".")
      else
        @short_name = hostname_components[0]
      end
    else
      @short_name = hostname
    end
    @node_server = NodeClient.new(hostname, testcase)
  end

  def addr_configserver
    @node_server.addr_configserver
  end

  # Returns the hostname stripped of the domain name.
  def short_name
    @short_name
  end

  def time
    @node_server.time
  end

  # Returns a reference to a remote object which is a subclass of VespaNode,
  # based on the given string _service_.
  def get_service(service)
    @node_server.get_service(service)
  end

  def cleanup_services
    @node_server.cleanup_services
  end

  def cleanup_coredumps(wanted_free_space)
    @node_server.cleanup_coredumps(wanted_free_space)
  end

  def remove_tmp_files
    @node_server.remove_tmp_files
  end

  def get_unblessed_processes
    @node_server.get_unblessed_processes
  end

  def kill_unblessed_processes
    @node_server.kill_unblessed_processes
  end

  def available_space
    @node_server.available_space
  end

  def stat_files(path, selector)
    return @node_server.stat_files(path, selector)
  end

  # Sync IO
  def sync
    @node_server.execute("sync")
  end

  def start_monitoring
    @node_server.start_monitoring
  end

  def stop_monitoring
    @node_server.stop_monitoring
  end

  def file_exist?(*args)
    @node_server.file_exist?(*args)
  end

  def file?(args)
    @node_server.file?(args)
  end

  def directory?(args)
    @node_server.directory?(args)
  end

  def create_tmp_bin_dir
    @node_server.create_tmp_bin_dir
  end

  def detect_sanitizers
    @node_server.detect_sanitizers
  end
  
  def setup_sanitizers
    @node_server.setup_sanitizers
  end

  def reset_sanitizers(cleanup)
    @node_server.reset_sanitizers(cleanup)
  end

  # Copies/renames single file from local src to dst (file) on node_server.
  # Target directory will be created if it does not exist.
  # Existing dst will be overwritten.
  def copy_local_file_to_remote_file(src, dst)
    assert_is_local_file(src)
    assert_is_remote_file_or_new(dst)

    src_dir = File.dirname(src)
    src_name = File.basename(src)
    dst_dir = File.dirname(dst)
    dst_name = File.basename(dst)

    private_copy_local_to_remote_and_rename(src_dir, dst_dir, src_name, dst_name)
  end

  # Copies single file from local src into dst (directory) on node_server.
  # Target directory will be created if it does not exist.
  # Existing file with the same name as src in dst will be overwritten.
  def copy_local_file_into_remote_directory(src, dst)
    assert_is_local_file(src)
    assert_is_remote_directory_or_new(dst)

    src_dir = File.dirname(src)
    src_name = File.basename(src)

    private_copy_local_to_remote(src_dir, dst, src_name)
  end

  # Copies the local directory src and places it inside the dst directory on the 
  # node_server, i.e. dst/{name of src}/{content of src}.
  # Target directory will be created if it does not exist.
  # Existing content in dst will be merged with new, src will take precedence.
  def copy_local_directory_into_remote_directory(src, dst)
    assert_is_local_directory(src)
    assert_is_remote_directory_or_new(dst)

    src_dir = File.dirname(src)
    src_name = File.basename(src)

    private_copy_local_to_remote(src_dir, dst, src_name)
  end

  # Copies the content of the local directory src into the dst directory on the 
  # node_server, i.e. dst/{content of src}
  # Target directory will be created if it does not exist.
  # Existing content in dst will be merged with new, src will take precedence.
  def copy_local_directory_to_remote_directory(src, dst)
    assert_is_local_directory(src)
    assert_is_remote_directory_or_new(dst)

    private_copy_local_to_remote(src, dst, "*")
  end

  # Copies/renames single file from src on node_server to local dst (file).
  # Target directory will be created if it does not exist.
  # Existing dst will be overwritten.
  def copy_remote_file_to_local_file(src, dst)
    assert_is_remote_file(src)
    assert_is_local_file_or_new(dst)

    src_dir = File.dirname(src)
    src_name = File.basename(src)
    dst_dir = File.dirname(dst)
    dst_name = File.basename(dst)

    private_copy_remote_to_local_and_rename(src_dir, dst_dir, src_name, dst_name)
  end

  # Copies single file from src on node_server into local dst (directory).
  # Target directory will be created if it does not exist.
  # Existing file with the same name as src in dst will be overwritten.
  def copy_remote_file_into_local_directory(src, dst)
    assert_is_remote_file(src)
    assert_is_local_directory_or_new(dst)

    src_dir = File.dirname(src)
    src_name = File.basename(src)

    private_copy_remote_to_local(src_dir, dst, src_name)
  end

  # Copies the src directory on the node_server and places it inside the local dst
  # directory, i.e. dst/{name of src}/{content of src}.
  # Target directory will be created if it does not exist.
  # Existing content in dst will be merged with new, src will take precedence.
  def copy_remote_directory_into_local_directory(src, dst)
    assert_is_remote_directory(src)
    assert_is_local_directory_or_new(dst)

    src_dir = File.dirname(src)
    src_name = File.basename(src)

    private_copy_remote_to_local(src_dir, dst, src_name)
  end

  # Copies the content of the src directory on the node_server into the local 
  # dst directory, i.e. dst/{content of src}
  # Target directory will be created if it does not exist.
  # Existing content in dst will be merged with new, src will take precedence.
  def copy_remote_directory_to_local_directory(src, dst)
    assert_is_remote_directory(src)
    assert_is_local_directory_or_new(dst)

    private_copy_remote_to_local(src, dst, "*")
  end

private
  # Not safe to call directly
  def private_copy_local_to_remote(src_dir, dst_dir, name)
    private_copy_local_to_remote_core(src_dir, dst_dir, name, rename_to = nil)
  end

  # Not safe to call directly
  def private_copy_local_to_remote_and_rename(src_dir, dst_dir, old_name, rename_to)
    private_copy_local_to_remote_core(src_dir, dst_dir, old_name, rename_to)
  end

  # Not safe to call directly
  def private_copy_remote_to_local(src_dir, dst_dir, name)
    private_copy_remote_to_local_core(src_dir, dst_dir, name, rename_to = nil)
  end

  # Not safe to call directly
  def private_copy_remote_to_local_and_rename(src_dir, dst_dir, old_name, rename_to)
    private_copy_remote_to_local_core(src_dir, dst_dir, old_name, rename_to)
  end

  # Core functionality of remote to local copy - not safe to call directly
  def private_copy_remote_to_local_core(src_dir, dst_dir, orig_name, rename_to)
    # Bundle remote files into archive    
    remote_tarfile =  @node_server.create_unique_temp_file("systemtest_copy_")
    cmd =  private_get_system_command_to_bundle_files_into_archive(src_dir, remote_tarfile, orig_name, rename_to) 
    @node_server.execute(cmd)

    # Copy remote archive to local archive
    local_tarfile = Tempfile.new("systemtest_copy_")
    content = readfile(remote_tarfile)
    File.open(local_tarfile.path, "w") do |file|
      file.write(content)
    end

    # Extract files locally
    FileUtils.mkdir_p(dst_dir)
    `cd #{dst_dir} && tar xzf #{local_tarfile.path}`

    # Remove temporary archives
    local_tarfile.close!();
    @node_server.execute("rm -f #{remote_tarfile}")
  end

  # Core functionality of local to remote copy - not safe to call directly
  def private_copy_local_to_remote_core(src_dir, dst_dir, orig_name, rename_to)
    # Bundle local files into archive    
    local_tarfile = Tempfile.new("systemtest_copy_")
    cmd =  private_get_system_command_to_bundle_files_into_archive(src_dir, local_tarfile.path, orig_name, rename_to)
    execute(cmd)

    # Copy archive to remote and extract
    @node_server.private_copy_archive_to_node_and_extract(local_tarfile.path, dst_dir, orig_name, rename_to)

    # Delete temporary archive
    local_tarfile.close!(); 
  end

  # Not safe to call directly
  def private_get_system_command_to_bundle_files_into_archive(src_dir, dst, orig_name, rename_to) 
    cmd = "cd #{src_dir} && tar -czf #{dst} #{orig_name}"
    if rename_to != nil
      cmd = cmd + " --transform 's/^#{orig_name}$/#{rename_to}/'"
    end
    return cmd
  end

  def assert_is_local_file(path)
    if !File.file?(path)
      raise path + " is not a local file."
    end
  end

  def assert_is_local_directory(path)
    if !File.directory?(path)
      raise path + " is not a local directory."
    end
  end

  def assert_is_remote_file(path)
    if !@node_server.file?(path)
      raise path + " is not a file on " + @name
    end
  end

  def assert_is_remote_directory(path)
    if !@node_server.directory?(path)
      raise path + " is not a directory on " + @name
    end
  end

  def assert_is_remote_directory_or_new(path)
    if @node_server.file_exist?(path) && !@node_server.directory?(path)
      raise "Destination " + path + " exists and is not a directory on " + @name
    end
  end

  def assert_is_remote_file_or_new(path)
    if @node_server.file_exist?(path) && !@node_server.file?(path)
      raise "Destination " + path + " exists and is not a file on " + @name
    end
  end

  def assert_is_local_directory_or_new(path)
    if File.exist?(path) && !File.directory?(path)
      raise "Destination " + path + " exists and is not a directory."
    end
  end

  def assert_is_local_file_or_new(path)
    if File.exist?(path) && !File.file?(path)
      raise "Destination " + path + " exists and is not a file."
    end
  end
end

