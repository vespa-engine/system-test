# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class InconsistentUpdates < VdsTest

  def setup
    @valgrind=false
    set_owner("vekterli")
    set_description("Test inconsistent updates")

    deploy_app(default_app.num_nodes(2).redundancy(2).
               config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
                      add('merge_operations_disabled', 'true')))
    start
  end

  def test_inconsistentupdates
    100.times { |i|
      doc = Document.new("music", "id:storage_test:music:n=#{i}:0").
        add_field("title", "title1")
      vespa.document_api_v1.put(doc)
    }

    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 0, "s:d");

    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')

    100.times { |i|
      doc = Document.new("music", "id:storage_test:music:n=#{i}:0").
        add_field("title", "title2")
      vespa.document_api_v1.put(doc)
    }

    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 0, "s:u");

    vespa.storage["storage"].storage["0"].wait_for_current_node_state('ui')

    feedfile(selfdir + "data/inconsistentupdate.json")

    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 0, "s:d");

    vespa.storage["storage"].storage["0"].wait_for_current_node_state('d')

    100.times { |i|
      doc = vespa.document_api_v1.get("id:storage_test:music:n=#{i}:0")
      assert_equal("title2", doc.fields["title"])
      assert_equal("artist", doc.fields["artist"])
    }
  end

  def teardown
    stop
  end

end
