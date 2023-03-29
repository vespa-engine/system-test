# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search/bucketreadiness/bucketreadiness_base'

class BucketReadiness < BucketReadinessBase

  def execute_visit(exec_object)
    exec_object.execute("vespa-visit -i | wc -l").to_i
  end

  def assert_visit_count(id, exp_count)
    act_count = vespa.adminserver.execute("vespa-visit -i 2>/dev/null | grep \"id:test\" | wc -l").to_i
    puts "******** assert_visit_count(#{id}, #{act_count}) ********"
    assert_equal(exp_count, act_count)
  end

  class VisitorRunner
    def initialize(exec_object, thread_id)
      @exec_object = exec_object
      @thread_id = thread_id
      @done = false
    end
    def mark_done
      @done = true
    end
    def run
      i = 0
      while !@done do
        count = @exec_object.execute("vespa-visit --priority LOWEST -i 2>/dev/null | grep \"id:test\" | sort | uniq | wc -l").to_i
        puts "******** vespa-visit(#{@thread_id},#{i}): #{count} ********"
        i += 1
      end
    end
  end

  def create_app_for_visiting
    app = create_app("regular/test.sd")
    app.config(ConfigOverride.new("vespa.config.content.core.stor-distributormanager").
               add("maxpendingidealstateoperations", 10000000))
    app.config(ConfigOverride.new("vespa.config.content.core.stor-server").
               add("max_merge_queue_size", 10000).
               add("max_merges_per_node", 40))
    app.config(ConfigOverride.new("vespa.config.content.core.stor-visitor").add("maxvisitorqueuesize", 100000))
    return app
  end

  def test_visiting_while_nodes_down_and_up
    set_description("Test that we can do visiting while nodes are going down and up")
    deploy_app(create_app_for_visiting)
    start

    docs = 10000
    generate_docs("doc.0.xml", 0, docs)
    feed_and_wait_for_hitcount(get_query(), docs, :file => @generated_dir + "/doc.0.xml")
    assert_visit_count(0, docs)
    visitors = []
    threads = []

    for i in 0...2 do
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["0"], i*4))
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["1"], 1+i*4))
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["2"], 2+i*4))
      visitors.push(VisitorRunner.new(vespa.storage["mycluster"].storage["3"], 3+i*4))
    end
    for i in 0...8 do
      thread = Thread.new(visitors[i]) do |v|
        v.run
      end
      threads.push(thread)
    end

    stop_and_wait(0)
    wait_for_hitcount(get_query("1,2,3"), docs)
    assert_visit_count(1, docs)

    stop_and_wait(1)
    wait_for_hitcount(get_query("2,3"), docs)
    assert_visit_count(2, docs)

    stop_and_wait(2)
    wait_for_hitcount(get_query("3"), docs)
    assert_visit_count(3, docs)

    # TODO this is temporary for debugging
    vespa.storage['mycluster'].set_bucket_crosscheck_params(
        :dump_distributor_db_states_on_failure => true
    )

    start_and_wait(0)
    wait_for_hitcount(get_query("0,3"), docs)
    assert_visit_count(4, docs)

    start_and_wait(1)
    wait_for_hitcount(get_query("0,1,3"), docs)
    assert_visit_count(5, docs)

    start_and_wait(2)
    wait_for_hitcount(get_query(), docs)
    assert_visit_count(6, docs)

    for i in 0...8 do
      visitors[i].mark_done
      threads[i].join
    end
  end

end
