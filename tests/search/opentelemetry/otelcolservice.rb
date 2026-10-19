# Copyright Vespa.ai. All rights reserved.

class OtelColService
  attr_reader :tls_env
  attr_reader :local_traces

  def initialize(testcase, tls_env, node_proxy, workdir, remote_workdir)
    @testcase = testcase
    @tls_env = tls_env
    @node_proxy = node_proxy
    @workdir = workdir
    @remote_workdir = remote_workdir
    @thread = nil
    file = 'traces.json'
    @local_traces = "#{@workdir}/#{file}"
    @remote_traces = "#{@remote_workdir}/#{file}"
  end

  def write_config
    text = <<-EOF
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 127.0.0.1:4317
        tls:
          cert_file: #{tls_env.certificate_file}
          key_file: #{tls_env.private_key_file}
          client_ca_file: #{tls_env.ca_certificates_file}
          min_version: "1.2"
          max_version: "1.3"
      http:
        endpoint: 127.0.0.1:4318
        tls:
          cert_file: #{tls_env.certificate_file}
          key_file: #{tls_env.private_key_file}
          client_ca_file: #{tls_env.ca_certificates_file}
          min_version: "1.2"
          max_version: "1.3"

processors:
  batch:
    timeout: 100ms
    send_batch_size: 8192
    send_batch_max_size: 0

exporters:
  file:
    path: traces.json

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [file]

  telemetry:
    logs:
      level: "info"
EOF
    FileUtils.mkdir_p(@workdir)
    File.open("#{@workdir}/otelcol-config.yaml", "w") do |file|
      file.print(text)
    end
    puts text
  end

  def start
    write_config
    @node_proxy.copy("#{@workdir}/otelcol-config.yaml", @remote_workdir)
    @thread = Thread.new do
      command="cd #{@remote_workdir} && /opt/vespa-deps/bin/vespa-otelcol --config otelcol-config.yaml"
      puts "Doing command '#{command}' on remote node"
      @node_proxy.execute(command, { :exceptiononfailure => false, :stderr => true })
    end
  end

  def stop
    return if @thread.nil?
    @node_proxy.kill_process('vespa-otelcol', {:signal => 'TERM'})
    @thread.join
    @thread = nil
    begin
      @node_proxy.copy_remote_file_to_local_file(@remote_traces, @local_traces)
    rescue StandardError => se
      puts "Failed to copy #{@local_traces}: #{se}"
    end
  end

  def write_host_hostname
    destdir = "#{Environment.instance.vespa_home}/conf/vespa/otel"
    FileUtils.mkdir_p(@workdir)
    File.open("#{@workdir}/host-hostname", "w") do |file|
      file.print("localhost")
    end
    @node_proxy.copy("#{@workdir}/host-hostname", destdir)
  end

  def puts(str)
    @testcase.puts(str)
  end

end
