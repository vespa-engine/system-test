# Copyright Vespa.ai. All rights reserved.

require 'cgi'
require 'uri'

# Triggers reindexing through the config server and follows its progress in the cluster controller.
# Mix in with `include Reindexing` in a TestCase subclass.
module Reindexing

  REINDEXING_POLL_INTERVAL_SECONDS = 1
  REINDEXING_LOG_EVERY_POLLS = 10

  # Triggers reindexing and redeploys `app` to start it (nil to redeploy yourself). Without cluster_id
  # and document_type, everything is reindexed. Returns { cluster_id => { document_type => ready_millis } }.
  def trigger_reindexing(app, cluster_id: nil, document_type: nil, indexed_only: false, speed: nil, cause: nil)
    before = ready_millis_by_cluster_and_type(application_reindexing_status)

    params = {}
    params['clusterId'] = cluster_id if cluster_id
    params['documentType'] = document_type if document_type
    params['indexedOnly'] = 'true' if indexed_only
    params['speed'] = speed.to_s if speed
    params['cause'] = cause if cause
    query = params.empty? ? '' : "?#{URI.encode_www_form(params)}"
    response = http_request_post(URI(reindexing_api_url('reindex') + query), {})
    assert(response.code.to_i == 200, "Triggering reindexing should give 200 response, got #{response.code}: #{response.body}")
    puts "Triggered reindexing: #{response.body}"

    after = ready_millis_by_cluster_and_type(application_reindexing_status)
    ready = {}
    after.each do |cluster, types|
      types.each do |type, ready_millis|
        previous = before.dig(cluster, type)
        if previous.nil? || previous < ready_millis
          (ready[cluster] ||= {})[type] = ready_millis
        end
      end
    end
    assert(!ready.empty?, "Triggering reindexing should advance the ready timestamp of at least one document type. Before: #{before}, after: #{after}")
    puts "Ready for reindexing: #{ready}"

    if app
      puts "Redeploying application to start reindexing"
      deploy_app(app)
    end
    ready
  end

  # Waits until a reindexing round readied at ready_millis has started.
  def wait_for_reindexing_to_start(cluster_id, document_type, ready_millis, timeout: 600)
    puts "Waiting for reindexing of '#{document_type}' in cluster '#{cluster_id}' to start, ready at #{Time.at(ready_millis / 1000)}"
    poll_reindexing_status(cluster_id, document_type, timeout, "start") do |status|
      status && status['startedMillis'] > ready_millis
    end
  end

  # Waits until the current reindexing round has ended and asserts success. Returns its duration in millis.
  def wait_for_reindexing_to_complete(cluster_id, document_type, timeout: 1800)
    puts "Waiting for reindexing of '#{document_type}' in cluster '#{cluster_id}' to complete"
    status = poll_reindexing_status(cluster_id, document_type, timeout, "complete") do |status|
      status && ['successful', 'failed'].include?(status['state'])
    end
    assert('successful' == status['state'], "Reindexing of '#{document_type}' in cluster '#{cluster_id}' should complete successfully, but status was #{status}")
    status['endedMillis'] - status['startedMillis']
  end

  # Waits for every pair returned by trigger_reindexing to start and complete. Returns their durations in millis.
  def wait_for_reindexing(ready, timeout: 1800)
    elapsed = {}
    ready.each do |cluster_id, types|
      types.each do |document_type, ready_millis|
        wait_for_reindexing_to_start(cluster_id, document_type, ready_millis, timeout: timeout)
        (elapsed[cluster_id] ||= {})[document_type] = wait_for_reindexing_to_complete(cluster_id, document_type, timeout: timeout)
      end
    end
    elapsed
  end

  # Asserts through an `indexing: now` attribute (default "#{document_type}_indexed_at_seconds") that
  # no documents were indexed before ready_millis and document_count were indexed after.
  def assert_documents_reindexed_after(ready_millis, document_count, document_type: nil, field: nil)
    raise ArgumentError, "Either document_type or field must be given" if document_type.nil? && field.nil?
    field ||= "#{document_type}_indexed_at_seconds"
    ready_seconds = ready_millis / 1000
    assert_hitcount("#{field}:#{CGI::escape('<')}#{ready_seconds}&nocache", 0)
    assert_hitcount("#{field}:#{CGI::escape('>')}#{ready_seconds}&nocache", document_count)
  end

  # Status from the cluster controller, or nil if none yet: startedMillis, state, endedMillis, progress, message.
  def reindexing_status(cluster_id, document_type)
    status = vespa.clustercontrollers['0'].get_reindexing_json
    return nil if status.nil?
    status.dig('clusters', cluster_id, 'documentTypes', document_type)
  end

  # Status of the whole application from the config server.
  def application_reindexing_status
    response = http_request_get(URI(reindexing_api_url('reindexing')), {})
    assert(response.code.to_i == 200, "Requesting reindexing status should give 200 response, got #{response.code}: #{response.body}")
    get_json(response)
  end

  private

  # Polls reindexing_status until the block returns true, and returns that status.
  def poll_reindexing_status(cluster_id, document_type, timeout, waiting_for)
    deadline = Time.now + timeout
    last_state = nil
    polls = 0
    loop do
      status = reindexing_status(cluster_id, document_type)
      state = status && status['state']
      if state != last_state || polls % REINDEXING_LOG_EVERY_POLLS == 0
        puts "Reindexing status for '#{document_type}' in cluster '#{cluster_id}': #{status.nil? ? 'none yet' : status}"
        last_state = state
      end
      return status if yield(status)
      assert(Time.now < deadline, "Timed out after #{timeout} seconds waiting for reindexing of '#{document_type}' in cluster '#{cluster_id}' to #{waiting_for}, last status was #{status}")
      sleep REINDEXING_POLL_INTERVAL_SECONDS
      polls += 1
    end
  end

  # { cluster_id => { document_type => ready_millis } } from the config server's status.
  def ready_millis_by_cluster_and_type(application_status)
    result = {}
    (application_status['clusters'] || {}).each do |cluster_id, cluster_status|
      (cluster_status['ready'] || {}).each do |document_type, type_status|
        ready_millis = type_status['readyMillis']
        (result[cluster_id] ||= {})[document_type] = ready_millis unless ready_millis.nil?
      end
    end
    result
  end

  # Config server application/v2 URL for the current application.
  def reindexing_api_url(path)
    tenant = use_shared_configservers ? @tenant_name : 'default'
    application = use_shared_configservers ? @application_name : 'default'
    hostname = vespa.nodeproxies.first[1].addr_configserver[0]
    "#{https_client.scheme}://#{hostname}:19071/application/v2/tenant/#{tenant}/application/#{application}/environment/prod/region/default/instance/default/#{path}"
  end

end
