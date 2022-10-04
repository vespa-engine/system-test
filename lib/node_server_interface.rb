# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

module NodeServerInterface

  def alive?
    @node_server.alive?
  end

  def shutdown
    @node_server.shutdown
  end

  def remote_eval(expr)
    @node_server.remote_eval(expr)
  end

  def execute(...)
    @node_server.execute(...)
  end

  def execute_bg(...)
    @node_server.execute_bg(...)
  end

  def get_pids(...)
    @node_server.get_pids(...)
  end

  def kill_process(...)
    @node_server.kill_process(...)
  end

  def kill_pid(...)
    @node_server.kill_pid(...)
  end

  def waitpid(...)
    @node_server.waitpid(...)
  end

  def print_configserver_stack
    @node_server.print_configserver_stack
  end

  def reset_logctl
    @node_server.reset_logctl
  end

  def set_addr_configserver(...)
    @node_server.set_addr_configserver(...)
  end

  def set_port_configserver_rpc(...)
    @node_server.set_port_configserver_rpc(...)
  end

  def reset_environment_setting
    @node_server.reset_environment_setting
  end

  def override_environment_setting(name, value)
    @node_server.override_environment_setting(name, value)
  end

  def get_stateline(path)
    @node_server.get_stateline(path)
  end

  def check_coredumps(...)
    @node_server.check_coredumps(...)
  end

  def find_coredumps(...)
    @node_server.find_coredumps(...)
  end

  def drop_coredumps(starttime)
    @node_server.drop_coredumps(starttime)
  end

  # starts vespa_base on remote node
  def start_base
    @node_server.start_base
  end

  # stops vespa_base on remote node
  def stop_base
    @node_server.stop_base
  end

  def start_configserver
    @node_server.start_configserver
  end

  def get_configserver_pid
    @node_server.get_configserver_pid
  end

  def stop_configserver(params={})
    @node_server.stop_configserver(params)
  end

  def ping_configserver
    @node_server.ping_configserver
  end

  def clean_indexes
    @node_server.clean_indexes
  end

  def feed(...)
    @node_server.feed(...)
  end

  def memusage_rss(...)
    @node_server.memusage_rss(...)
  end

  def create_tmpfeed(...)
    @node_server.create_tmpfeed(...)
  end

  def feedfile(...)
    @node_server.feedfile(...)
  end

  def feedbuffer(...)
    @node_server.feedbuffer(...)
  end

  def feed_stream(...)
    @node_server.feed_stream(...)
  end

  def memory_rss(...)
    @node_server.memory_rss(...)
  end

  def fetchfile(...)
    @node_server.fetchfile(...)
  end

  def fetchfiles(...)
    @node_server.fetchfiles(...)
  end

  def copy(...)
    @node_server.copy(...)
  end

  def stat_files(...)
    @node_server.stat_files(...)
  end

  def wait_until_file_exists(...)
    @node_server.wait_until_file_exists(...)
  end

  def write_document_operations(...)
    @node_server.write_document_operations(...)
  end

  def write_queries(...)
    @node_server.write_queries(...)
  end

  def write_urls(...)
    @node_server.write_urls(...)
  end

  def writefile(...)
    @node_server.writefile(...)
  end

  def readfile(*args)
    content = ''
    ret = @node_server.readfile(*args) do |buf|
      content += buf
      nil
    end
    if ret
      content
    else
      false
    end
  end

  def hostname
    @node_server.hostname
  end

  def port_configserver_rpc
    @node_server.port_configserver_rpc
  end

  def removefile(...)
    @node_server.removefile(...)
  end

  def list_files(...)
    @node_server.list_files(...)
  end

  def resolve_symlink(...)
    @node_server.resolve_symlink(...)
  end

  def set_bash_variable(...)
    @node_server.set_bash_variable(...)
  end

  def unset_bash_variable(...)
    @node_server.unset_bash_variable(...)
  end

  def maven_compile(...)
    @node_server.maven_compile(...)
  end

  def compile_java(...)
    @node_server.compile_java(...)
  end

  def compile_cpp(...)
    @node_server.compile_cpp(...)
  end

  def delete_java(...)
    @node_server.delete_java(...)
  end

  def generate_build_script(...)
    @node_server.generate_build_script(...)
  end

  def generate_delete_script(...)
    @node_server.generate_delete_script(...)
  end

  def runqueries(...)
    @node_server.runqueries(...)
  end

  def run_fbench(...)
    @node_server.run_fbench(...)
  end

  def run_multiple_fbenches(...)
    @node_server.run_multiple_fbenches(...)
  end

  def performance_snapshot
    @node_server.performance_snapshot
  end

  def http_server_make(...)
    @node_server.http_server_make(...)
  end

  def http_server_handler(port, &block)
    @node_server.http_server_handler(port, &block)
  end

  def http_server_start(...)
    @node_server.http_server_start(...)
  end

  def http_server_stop(...)
    @node_server.http_server_stop(...)
  end

  def file_exist?(...)
    @node_server.file_exist?(...)
  end
 
  def file?(...)
    @node_server.file?(...)
  end

  def create_unique_temp_file(...)
    @node_server.create_unique_temp_file(...)
  end

  def directory?(...)
    @node_server.directory?(...)
  end

  def get_current_time_as_int
    @node_server.get_current_time_as_int
  end
 
  def create_tmp_bin_dir
    @node_server.create_tmp_bin_dir
  end

  def setup_sanitizer(name)
    @node_server.setup_sanitizer(name)
  end

  def reset_sanitizer(cleanup)
    @node_server.reset_sanitizer(cleanup)
  end
end
