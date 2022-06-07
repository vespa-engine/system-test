# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class OperationPriorityBlocking < VdsTest

  BLOCKING_DISABLED = -1

  def setup
    set_owner('vekterli')
    set_description('Test that external feed operations with a priority less ' +
                    'than a configured level can be blocked, and that this ' +
                    'is a live change')
    deploy_app(app_with_priority_threshold(BLOCKING_DISABLED))
    start
  end

  def teardown
    stop
  end

  def app_with_priority_threshold(threshold)
    default_app.config(ConfigOverride.new('vespa.config.content.core.stor-bouncer').
                       add('feed_rejection_priority_threshold', threshold))
  end

  def doc_id(id_specific)
    "id:foo:music::#{id_specific}"
  end

  def make_doc(id_specific)
    Document.new('music', doc_id(id_specific)).
        add_field('title', 'foo')
  end

  def put_doc(doc, priority:'NORMAL_3')
    puts "Putting document '#{doc.documentid}'"
    feedbuffer(doc.to_put_json(true), {:json => true, :client => :vespa_feed_client, :priority => priority})
  end

  def run_vespa_get(args)
    vespa.storage['storage'].storage["0"].execute("vespa-get " + args).strip
  end

  def get_doc(id_specific, priority:)
    run_vespa_get("--printids --priority #{priority} #{doc_id(id_specific)}")
  end

  def put_and_verify_doc(doc, priority:'NORMAL_3')
    put_doc(doc, priority: priority)
    result = run_vespa_get("--printids #{doc.documentid}")
    assert_equal(doc.documentid, result)
  end

  # The actual integral value that a particular priority name maps to is
  # specified in the stor-prioritymapping config, so instead of hardcoding
  # these in the test and hoping no one changes anything we look up the
  # mappings on-demand.
  def priority_int_value_of(name)
    node = vespa.storage['storage'].storage['0']
    config = node.execute("vespa-get-config -n vespa.config.content.core.stor-prioritymapping " +
                          "-i #{node.config_id}", :noecho => true)
    if config !~ /#{name} (\d+)/im
      raise "Could not find a priority mapping for enum value #{name}"
    end
    return $~[1].to_i
  end

  def deploy_with_threshold(priority_name)
    puts "----"
    puts "Deploying app with priority threshold of '#{priority_name}'"
    puts "----"
    output = deploy_app(app_with_priority_threshold(priority_int_value_of(priority_name)))
    config_generation = get_generation(output).to_i

    # deploy_app does not wait until config has been propagated, so we have to
    # do this explicitly here to avoid test race conditions between deployment
    # and feeding.
    wait_for_reconfig(config_generation)
    vespa.storage['storage'].wait_until_content_nodes_have_config_generation(config_generation)
  end

  def test_feed_ops_with_low_priority_can_be_blocked
    # Will be allowed through, since priority blocking is disabled.
    put_and_verify_doc(make_doc(1), priority: 'LOWEST')
    put_and_verify_doc(make_doc(2), priority: 'NORMAL_3')
    deploy_with_threshold('NORMAL_2')

    # Will fail with REJECTED, as NORMAL_3 is lower pri than NORMAL_2.
    result = put_doc(make_doc(3), priority: 'NORMAL_3')
    assert_match(/REJECTED, Operation priority \(120\) is lower than currently configured threshold \(110\)/, result)

    # Get is a non-mutating external operation and should always be allowed through.
    assert_equal(doc_id(2), get_doc(2, priority: 'LOWEST'))

    # Configure so that NORMAL_3 will once again pass.
    deploy_with_threshold('NORMAL_4')
    put_and_verify_doc(make_doc(4), priority: 'NORMAL_3')
  end

end
