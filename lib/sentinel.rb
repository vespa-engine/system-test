# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rpc/rpcwrapper'

class Sentinel

  NAP_TIME = 0.1

def initialize(testcase, tls_env = nil)
  @testcase = testcase
  @rpcwrap = nil
  @tls_env = tls_env
end

def do_ls_cmd
  begin
    value = rpcwrapper().sentinel_ls()
    return value[0]
  rescue StandardError => e
    @testcase.output("error doing sentinel 'ls' command: #{e}")
  end
  return ""
end

def get_state(service)
  str = do_ls_cmd
  str.each_line do |line|
    if line =~ Regexp.new('(.*) state=([A-Z]*)') then
      if ($1 == service) then
        @testcase.output("state for #{service} is #{$2}")
        return $2
      end
    end
  end
  @testcase.output("No valid state for '#{service}' (got '#{str}')")
  return "UNKNOWN"
end

def get_pid(service)
  str = do_ls_cmd
  str.each_line do |line|
    if line =~ /#{service} .*pid=(\d+)/ then
      @testcase.output("pid for #{service} is #{$1}")
      return $1
    end
  end
  return nil
end

def do_stop_cmd(service)
  begin
    rpcwrapper().sentinel_service_stop(service)
  rescue StandardError => e
    @testcase.output("error doing sentinel 'stop(#{service})' command: #{e}")
  end
end

def stop_service(service, timeout, force = false)
  @testcase.output("Stopping service: " + service + (force ? " (force)" : ""))
  pid = get_pid(service)
  do_stop_cmd(service)
  count = 0
  while (true) do
    state = get_state(service)
    if (state == "FINISHED" || state == "TERMINATED" || (force && state == "FAILED")) then
      @testcase.output("Service: " + service + " is: " + state)
      return true
    end
    count = count + 1
    sleep NAP_TIME
    if (force && count == timeout)
      cmd = "kill -9 #{pid} 2>&1"
      output = `#{cmd}`
      @testcase.output("#{cmd}: #{output}")
    end
    if (NAP_TIME*count > timeout) then
      @testcase.output("Timeout, service: " + service + " not stopped, state: " + state)
      return false
    end
  end
end

def do_start_cmd(service)
  begin
    rpcwrapper().sentinel_service_start(service)
  rescue StandardError => e
    @testcase.output("error doing sentinel 'start(#{service})' command: #{e}")
  end
end

def start_service(service, timeout)
  @testcase.output("Starting service: " + service)
  do_start_cmd(service)
  count = 0
  while (true) do
    state = get_state(service)
    if (state == "RUNNING") then
      @testcase.output("Service started: " + service)
      return true
    else
      sleep NAP_TIME
      count = count + 1
      if (NAP_TIME*count > timeout) then
        @testcase.output("Timeout, service not started: " + service)
        return false
      end
    end
  end
end

private
def rpcwrapper
  @rpcwrap or @rpcwrap = RpcWrapper.new("localhost", 19097, @tls_env)
end

end
