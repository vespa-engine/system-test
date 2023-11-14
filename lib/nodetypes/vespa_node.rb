# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'net/http'
require 'uri'
require 'json'
require 'json_metrics'
require 'performance/stat'
require 'http_connection_pool'
require 'environment'
require 'https_client'

class VespaNode
  include DRb::DRbUndumped, NodeServerInterface

  attr_reader :name, :servicetype, :testcase, :config_id, :https_client
  attr_accessor :service, :index, :cluster, :ports, :ports_by_tag

  def initialize(service_entry, testcase, node_server)
    @service_entry = service_entry
    @testcase = testcase
    @node_server = node_server
    @https_client = node_server.https_client

    if service_entry
      @config_id = service_entry["config-id"]
      @servicetype = service_entry["servicetype"]
      @index = service_entry["index"].to_s
      @cluster = service_entry["clustername"]
      @service = service_entry["servicename"]
      @name = service_entry["hostname"]
      @ports = service_entry["ports"]
      @ports_by_tag = service_entry["ports_by_tag"]
    end
  end

  def tls_env
    @node_server.tls_env
  end

  def with_https_connection(hostname, port, path)
    @https_client.with_https_connection(hostname, port, path) { |conn, uri|
      yield(conn, uri)
    }
  end

  def with_custom_https_connection(cert_file, private_key_file, ca_cert_file, hostname, port)
    http = Net::HTTP.new(hostname, port)
    http.use_ssl = true
    http.ca_file = ca_cert_file unless ca_cert_file == nil
    http.cert = OpenSSL::X509::Certificate.new(File.read(cert_file)) unless cert_file == nil
    http.key = OpenSSL::PKey::RSA.new(File.read(private_key_file)) unless private_key_file == nil
    http.verify_mode = tls_env.ssl_ctx.verify_mode
    http.ssl_version = :TLSv1_2  # TODO allow TLSv1.3 once https://bugs.ruby-lang.org/issues/19017 is resolved
    http.start { |conn|
      yield(conn)
    }
  end

  def https_get(hostname, port, path, headers={})
    @https_client.get(hostname, port, path, headers: headers)
  end

  def get_json_over_http(full_path, port, hostname = Environment.instance.vespa_hostname)
    begin
      res = https_get(hostname, port, full_path)
      raise("error!") unless res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    rescue JSON::ParserError => e
      begin
        # Parse again, but with linebreaks this time, for more
        # sensible error message.
        JSON.parse(res.body.gsub("}", "}\n"))
      rescue Exception => e
        @testcase.output(e.message)
        @testcase.output(e.backtrace.inspect)
        raise e
      end
    rescue Exception => e
      #@testcase.output(e.message)
      #@testcase.output(e.backtrace.inspect)
      raise e
    end
  end

  def get_state_port
    @ports_by_tag["state"]
  end

  def get_state_v1(path)
    60.times do
      begin
        response = get_json_over_http("/state/v1/#{path}", get_state_port)
        if response != nil
          return response
        end
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        # Node likely not up yet; retry transparently.
      end
      sleep 1
    end
    nil
  end

  def get_state_v1_metrics
    get_state_v1('metrics')
  end

  def get_state_v1_config
    get_state_v1('config')
  end

  def use_min_config_generation
    return false
  end

  def wait_for_config_generation(wanted_config_generation, wait_time=60)
    service = "#{self.config_id} on host #{self.hostname}"
    puts "#{service}: Waiting for config generation #{wanted_config_generation}"
    start = Time.now.to_i
    generation = 0
    wait_time = 180 if @testcase.valgrind
    begin
      json = get_state_v1_config
      if json
        generation = json["config"]["generation"]
        if use_min_config_generation
          json["config"].each do | component, val |
            next if component == "generation"
            next unless val.has_key?("generation")
            componentgeneration = val["generation"]
            if generation.nil? || (!componentgeneration.nil? && generation > componentgeneration)
              generation = componentgeneration
            end
          end
        else
          if ! generation
              # Second level varies between services, use the first
              generation = json["config"].values.first["generation"]
          end
        end
      end
      sleep_time = 0.1
      sleep_time = 3 if @testcase.valgrind
      sleep sleep_time
    end while ((generation != wanted_config_generation) and ((Time.now.to_i - start) < wait_time))
    if generation != wanted_config_generation
      raise "#{service} did not get config with generation #{wanted_config_generation} in #{wait_time} seconds (was running with config generation #{generation})"
    end
  end

  def get_total_metrics
    # this is not an external API and may not be supported by all services.
    # retry because we are able to get metrics from the start, which means
    # the metrics HTTP server might not be available yet.
    60.times do
      begin
        metrics = get_json_over_http("/metrics/total", get_state_port)
        return JSONMetrics.new(metrics)
      rescue StandardError => e
        sleep 1
      end
    end
    nil
  end

  def stop(force = false)
    return Sentinel.new(@testcase, tls_env()).stop_service(service, 50, force)
  end

  def kill()
    pid = Sentinel.new(@testcase, tls_env()).get_pid(service)
    @testcase.output("pid of #{service} is #{pid}")
    cmd = "kill #{pid} 2>&1"
    output = `#{cmd}`
    @testcase.output("#{cmd}: #{output}")
  end

  def start
    return Sentinel.new(@testcase, tls_env()).start_service(service, 20)
  end

  def restart
    stop
    start
  end

  def get_state
    return Sentinel.new(@testcase, tls_env()).get_state(service)
  end

  # Alias of get_state to avoid issues with this particular
  # method being overridden with incompatible semantics by Searchnode.
  alias :get_sentinel_state :get_state

  def get_pid
    return Sentinel.new(@testcase, tls_env()).get_pid(service)
  end

  def logctl(service_spec, level_mods)
    if not @testcase.leave_loglevels
      execute("vespa-logctl -c #{service_spec} #{level_mods} >/dev/null", :exceptiononfailure => false)
    end
  end

  def logctl2(service_spec, level_mods)
    if not @testcase.leave_loglevels
      puts "vespa-logctl -c #{@service}:#{service_spec} #{level_mods}"
      execute("vespa-logctl -c #{@service}:#{service_spec} #{level_mods}",
              :exceptiononfailure => false)
    end
  end

  # match _regexp_ with vespa.log, and return the number of matches
  def log_matches(regexp)
    logcontent = File.open("#{Environment.instance.vespa_home}/logs/vespa/vespa.log").read
    # scan returns an array. log_matches returns the size of it.
    logcontent.scan(regexp).size
  end

  # The time on this Vespa node.
  def time
    Time.new
  end

  def to_s
    string_repr = ""
    if @service_entry
      @service_entry.each do |key, value|
        string_repr += "#{key}:#{value} "
      end
    else
      string_repr += "no service type set"
    end
    return string_repr.chomp
  end

  def performance_snapshot
    Perf::Stat::create_snapshot
  end

  def pids_with_config_id
      execute("pgrep -f '#{self.config_id}'", :exceptiononfailure => true).split
  end

  def dump_jmap
    timestamp = Time.now.to_i
    begin
      pids = pids_with_config_id
      pids.each { |p|
         execute("/usr/bin/sudo -u #{Environment.instance.vespa_user} jmap -dump:live,format=b,file=/tmp/docproc-#{timestamp}.#{p}.hprof #{p}")
      }
    rescue Exception => e
      puts e
    end
  end

  def dumpJStack
    begin
      pids = pids_with_config_id
      pids.each { |p|
        puts execute("/usr/bin/sudo -u #{Environment.instance.vespa_user} jstack -l #{p}", :exceptiononfailure => false)
      }
    rescue Exception => e
      puts e
    end
  end

  def dumpPStack
    begin
      pids = pids_with_config_id

      pids.each { |p|
        puts execute("/usr/bin/sudo -u #{Environment.instance.vespa_user} pstack #{p}", :exceptiononfailure => false)
      }
    rescue Exception => e
      puts e
    end
  end

  def cleanup
    # Do nothing
  end

end
