# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MaintenanceControllerTest < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def assert_job_executed(job)
    puts "assert_job_executed(): job='#{job}'"
    wait_for_atleast_log_matches(/runJobInExecutor.*job='#{job}'/, 1)
  end

  def assert_job_metric(name)
    full_name = "content.proton.documentdb.job.#{name}"
    value = vespa.search["search"].first.get_total_metrics.get(full_name)["average"]
    puts "#{full_name}['average']=#{value}"
    assert(value > 0.0)
  end

  def test_maintenance_controller_jobs_executed
    set_description("Test that the maintenance controller jobs in proton are executed")
    deploy_same_app(10.0)
    start
    vespa.adminserver.logctl("searchnode:proton.server.maintenancejobrunner", "debug=on")
    verify_jobs_executed
  end

  def deploy_same_app(interval, sd="1/test.sd")
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new.sd(selfdir + sd).
                       config(ConfigOverride.new("vespa.config.search.core.proton").
                              add("pruneremoveddocumentsinterval", interval).
                              add("periodic", ConfigValue.new("interval", interval)).
                              add("lidspacecompaction", ConfigValue.new("interval", interval)))))
  end

  def test_maintenance_controller_jobs_executed_also_after_reconfig_bug_7213595
    set_description("Test that the maintenance controller jobs in proton are executed also after reconfig.")
    deploy_same_app(60.0)
    start
    vespa.adminserver.logctl("searchnode:proton.server.maintenancejobrunner", "debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.maintenancecontroller", "debug=on")
    deploy_same_app(60.0, "2/test.sd")
    verify_jobs_executed
  end

  def verify_jobs_executed
    assert_job_executed("prune_removed_documents.test")
    assert_job_metric("removed_documents_prune")
    assert_job_executed("lid_space_compaction\.test\.0\.ready")
    assert_job_executed("lid_space_compaction\.test\.1\.removed")
    assert_job_executed("lid_space_compaction\.test\.2\.notready")
    assert_job_metric("lid_space_compact")
    assert_job_executed("heart_beat")
  end

  def teardown
    stop
  end

end
