# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Coverage < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
    add_ignorable_messages([/group \d has reduced coverage/])
    @num_documents = 10_000
    @simple_query = {"query" => "sddocname:coverage"}
  end

  def doc_template
    '{ "put": "id:coverage:coverage::$seq()", "fields": { "int_field": $seq() } }'
  end

  def feed_and_wait
    feed_stream(DataGenerator.new.feed_command(template: doc_template, count: @num_documents), {})
    wait_for_hitcount(@simple_query, @num_documents)
  end

  def feed_and_wait_and_stop
    feed_and_wait
    vespa.stop_content_node("mycluster", 0, 120, "d")
  end

  def create_app(schema_file, num_groups, num_nodes_per_group, redundancy, ready_copies, distribution)
    SearchApp.new.sd(selfdir + "coverage.sd")

    topgroup = NodeGroup.new(0, "mytopgroup").distribution(distribution)
    distkey = 0
    for g in 1..num_groups do
      nodegroup = NodeGroup.new(g-1, "mygroup#{g-1}")
      for n in 1..num_nodes_per_group do
        nodegroup.node(NodeSpec.new("node1", distkey))
        distkey = distkey + 1
      end
      topgroup.group(nodegroup)
    end

    SearchApp.new.cluster(SearchCluster.new("mycluster")
                                       .sd(schema_file)
                                       .redundancy(redundancy)
                                       .ready_copies(ready_copies)
                                       .min_active_docs_coverage(100.0) # Should make no difference for the test. For toying around with
                                       .group(topgroup))
  end

  def test_coverage_when_stopping_node_with_one_group_with_redundancy
    set_description("Check reported coverage when a node in a group is stopped with one groups and redundant documents on the other node")
    deploy_app(create_app(selfdir + "coverage.sd", 1, 2, 2, 1, "*"))
    start

    feed_and_wait_and_stop

    wait_for_hitcount_from_group(@simple_query, nil, @num_documents)
    wait_for_coverage_from_group(@simple_query, nil, 100)
  end

  def test_coverage_when_stopping_node_with_one_group_without_redundancy
    set_description("Check reported coverage when a node in a group is stopped with one groups and no redundant documents on the other node")
    deploy_app(create_app(selfdir + "coverage.sd", 1, 2, 1, 1, "*"))
    start

    feed_and_wait_and_stop

    # No need to wait for hitcount. Will be around @num_documents / 2 and not change since there is no redundancy.
    wait_for_coverage_from_group(@simple_query, nil, 50)
  end

  def test_coverage_when_stopping_node_with_two_groups_without_redundancy
    set_description("Check reported coverage when a node in a group is stopped with two groups in total and no inner-group redundancy")
    deploy_app(create_app(selfdir + "coverage.sd", 2, 2, 2, 2, "1|*"))
    start

    feed_and_wait_and_stop

    wait_for_hitcount_from_group(@simple_query, 0, @num_documents)
    wait_for_hitcount_from_group(@simple_query, 1, @num_documents)
    wait_for_coverage_from_group(@simple_query, 0, 100)
    wait_for_coverage_from_group(@simple_query, 1, 100)
  end

  def test_coverage_when_stopping_node_with_two_groups_with_redundancy
    set_description("Check reported coverage when a node in a group is stopped with two groups in total and inner-group redundancy")
    deploy_app(create_app(selfdir + "coverage.sd", 2, 2, 4, 2, "2|*"))
    start

    feed_and_wait_and_stop

    wait_for_hitcount_from_group(@simple_query, 0, @num_documents)
    wait_for_hitcount_from_group(@simple_query, 1, @num_documents)
    wait_for_coverage_from_group(@simple_query, 0, 100)
    wait_for_coverage_from_group(@simple_query, 1, 100)
  end

  def wait_for_hitcount_from_group(query, wanted_group, wanted_hitcount, timeout_in=60, qrserver_id=0, params={})
    query = query.merge({"hits" => "1", "model.searchGroup" => "#{wanted_group}"})

    hitcount = -1
    group = -1
    timeout = timeout_in
    timeout = calculateQueryTimeout(timeout)

    puts "Waiting for #{wanted_hitcount} hits from group #{wanted_group}, timeout: #{timeout}"
    trynum = 0
    start = Time.now.to_i

    while Time.now.to_i < start + timeout
      begin
        trynum += 1
        result = search_with_timeout(timeout_in, query, qrserver_id, {}, false, params)
        hitcount = result.hitcount
        group = result.json['root']['fields']['searchGroup']
        if hitcount == wanted_hitcount && (wanted_group == nil || group == wanted_group)
          puts "Success on try #{trynum}: Got #{wanted_hitcount} hits from group #{wanted_group}"
          return true
        else
          puts "Failure on try #{trynum}: Expected #{wanted_hitcount} hits from group #{wanted_group}, got #{hitcount} hits from group #{group}"
        end
      rescue StandardError => e
        puts "error #{e}: #{e.backtrace}"
      rescue Interrupt
        puts "low-level timeout, retry"
      end
      sleep 1
    end
    fail("Timeout after #{trynum} tries: Expected #{wanted_hitcount} hits from group #{wanted_group}, got #{hitcount} hits from group #{group}")
  end

end
