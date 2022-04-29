# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

module NodeServerInterface

  def shutdown
    @node_server.shutdown
  end
  def remote_eval(expr)
    @node_server.remote_eval(expr)
  end

  def execute(*args)
    @node_server.execute(*args)
  end

  def execute_bg(*args)
    @node_server.execute_bg(*args)
  end

  def get_pids(*args)
    @node_server.get_pids(*args)
  end

  def kill_process(*args)
    @node_server.kill_process(*args)
  end

  def kill_pid(*args)
    @node_server.kill_pid(*args)
  end

  def waitpid(*args)
    @node_server.waitpid(*args)
  end

  def print_configserver_stack
    @node_server.print_configserver_stack
  end

  def reset_logctl
    @node_server.reset_logctl
  end

  def set_addr_configserver(*args)
    @node_server.set_addr_configserver(*args)
  end

  def set_port_configserver_rpc(*args)
    @node_server.set_port_configserver_rpc(*args)
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

  def check_coredumps(*args)
    @node_server.check_coredumps(*args)
  end

  def find_coredumps(*args)
    @node_server.find_coredumps(*args)
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

  def feed(*args)
    @node_server.feed(*args)
  end

  def memusage_rss(*args)
    @node_server.memusage_rss(*args)
  end

  def create_tmpfeed(*args)
    @node_server.create_tmpfeed(*args)
  end

  def feedfile(*args)
    @node_server.feedfile(*args)
  end

  def feedbuffer(*args)
    @node_server.feedbuffer(*args)
  end

  def feed_stream(*args)
    @node_server.feed_stream(*args)
  end

  def memory_rss(*args)
    @node_server.memory_rss(*args)
  end

  def fetchfile(*args)
    @node_server.fetchfile(*args)
  end

  def fetchfiles(*args)
    @node_server.fetchfiles(*args)
  end

  def copy(*args)
    @node_server.copy(*args)
  end

  def stat_files(*args)
    @node_server.stat_files(*args)
  end

  def wait_until_file_exists(*args)
    @node_server.wait_until_file_exists(*args)
  end

  def write_document_operations(*args)
    @node_server.write_document_operations(*args)
  end

  def write_queries(*args)
    @node_server.write_queries(*args)
  end

  def write_urls(*args)
    @node_server.write_urls(*args)
  end

  def writefile(*args)
    @node_server.writefile(*args)
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

  def removefile(*args)
    @node_server.removefile(*args)
  end

  def list_files(*args)
    @node_server.list_files(*args)
  end

  def resolve_symlink(*args)
    @node_server.resolve_symlink(*args)
  end

  def set_bash_variable(*args)
    @node_server.set_bash_variable(*args)
  end

  def unset_bash_variable(*args)
    @node_server.unset_bash_variable(*args)
  end

  def maven_compile(*args)
    @node_server.maven_compile(*args)
  end

  def compile_java(*args)
    @node_server.compile_java(*args)
  end

  def compile_cpp(*args)
    @node_server.compile_cpp(*args)
  end

  def delete_java(*args)
    @node_server.delete_java(*args)
  end

  def generate_build_script(*args)
    @node_server.generate_build_script(*args)
  end

  def generate_delete_script(*args)
    @node_server.generate_delete_script(*args)
  end

  def runqueries(*args)
    @node_server.runqueries(*args)
  end

  def run_fbench(*args)
    @node_server.run_fbench(*args)
  end

  def run_multiple_fbenches(*args)
    @node_server.run_multiple_fbenches(*args)
  end

  def performance_snapshot
    @node_server.performance_snapshot
  end

  # Methods used for VDS stability testing

  def vdsstability_initialize(webserver_enabled, doccount, usercount)
    @node_server.vdsstability_initialize(webserver_enabled, doccount, usercount)
  end

  def vdsstability_start_load(loadgiver_id, type, rate, numdocs=100, seed=0)
    @node_server.vdsstability_start_load(loadgiver_id, type, rate, numdocs, seed)
  end

  def vdsstability_start_populate(loadgiver_id, numdocs, seed=0)
    @node_server.vdsstability_start_populate(loadgiver_id, numdocs, seed)
  end

  def vdsstability_start_visit_load(loadgiver_id)
    @node_server.vdsstability_start_visit_load(loadgiver_id)
  end

  def vdsstability_stop_load(loadgiver_id)
    @node_server.vdsstability_stop_load(loadgiver_id)
  end

  def vdsstability_get_status
    @node_server.vdsstability_get_status
  end

  def vdsstability_dumpall
    @node_server.vdsstability_dumpall
  end

  def vdsstability_disable_errors(loadgiver_id)
    @node_server.vdsstability_disable_errors(loadgiver_id)
  end

  def vdsstability_enable_errors(loadgiver_id)
    @node_server.vdsstability_enable_errors(loadgiver_id)
  end

  def vdsstability_get_errors(loadgiver_id)
    @node_server.vdsstability_get_errors(loadgiver_id)
  end

  def vdsstability_is_done?(loadgiver_id)
    @node_server.vdsstability_is_done?(loadgiver_id)
  end

  def vdsstability_num_pending
    @node_server.vdsstability_num_pending
  end

  def vdsstability_stop
    @node_server.vdsstability_stop
  end

  def http_server_make(*args)
    @node_server.http_server_make(*args)
  end

  def http_server_handler(port, &block)
    @node_server.http_server_handler(port, &block)
  end

  def http_server_start(*args)
    @node_server.http_server_start(*args)
  end

  def http_server_stop(*args)
    @node_server.http_server_stop(*args)
  end

  def file_exist?(*args)
    @node_server.file_exist?(*args)
  end
 
  def file?(*args)
    @node_server.file?(*args)
  end

  def create_unique_temp_file(*args)
    @node_server.create_unique_temp_file(*args)
  end

  def directory?(*args)
    @node_server.directory?(*args)
  end


  def vdsstability_do_command(*args)
    if block_given?
      @node_server.vdsstability_do_command(*args) do |buf|
        yield buf
      end
    else
      @node_server.vdsstability_do_command(*args)
    end
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
