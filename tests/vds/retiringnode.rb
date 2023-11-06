# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'vds_test'

class RetiringNode < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(3).redundancy(2))
    start
  end

  def test_putandretirestatic
    puts "Put 50 documents"
    putdocs(50, 0)

    10.times { |i|
      puts "Check that doc 0 is on both nodes"
      res = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//" + i.to_s + "/test")
      assert_equal(2, res.size())
    }

    puts "Retire storage node 1"
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 1, "s:r");
    vespa.storage["storage"].storage["1"].wait_for_current_node_state("r");
    vespa.storage["storage"].wait_until_ready(200)

    10.times { |i|
      puts "Check that no docs are on 1."
      res = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//" + i.to_s + "/test")
      assert_equal(2, res.size())
      assert_equal("OK", res["0"]["status"])
      assert_equal("OK", res["2"]["status"])
    }
  end

  def test_putandretiredynamic
    puts "Putting 50 documents"
    putdocs(50, 0)

    puts "Retire storage node 1"
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 1, "s:r");

    puts "Wait until state is retiring"
    vespa.storage["storage"].storage["1"].wait_for_current_node_state("r");

    puts "Put 50 more docs while retiring"
    putdocs(50, 50)

    puts "Wait until ready"
    vespa.storage["storage"].wait_until_ready(100)

    10.times { |i|
      puts "Check that no docs are on 1."
      res = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//" + i.to_s + "/test")
      assert_equal(2, res.size())
      assert_equal("OK", res["0"]["status"])
      assert_equal("OK", res["2"]["status"])
    }

    10.times { |i|
      puts "Check that no docs are on 1."
      res = vespa.storage["storage"].storage["0"].stat("id:crawler:music::http//" + (i + 50).to_s + "/test")
      assert_equal(2, res.size())
      assert_equal("OK", res["0"]["status"])
      assert_equal("OK", res["2"]["status"])
    }
  end

  def putdocs(count, index)
    count.times do
      doc = Document.new("music", "id:crawler:music::http//" + index.to_s + "/test").
        add_field("title", "title " + index.to_s).
        add_field("artist", "artist " + index.to_s)
      vespa.document_api_v1.put(doc)
      index = index + 1
    end
  end

  def get_last_numdocs(node)
      mnam = 'vds.datastored.alldisks.docs'
      mm = node.get_metrics_matching(mnam)
      if (mm && mm[mnam] && mm[mnam]['last'])
        lastval = mm[mnam]['last']
        return lastval.to_i
      end
      flunk "Missing metric[#{mnam}][last], got: #{mm}"
  end

  def test_retire_doccount
    ['', '2', '3'].each do |node|
      vespa.storage['storage'].storage['0'].execute("vespa-logctl searchnode#{node}:persistence.filestor.manager debug=on")
    end

    puts "Retire storage node 1"
    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 2, "s:r");

    vespa.storage["storage"].storage["2"].wait_for_current_node_state("r");

    puts "Feed some documents"
    100.times{|i|
      doc = Document.new("music", "id:test:music::#{i}:")
      vespa.document_api_v1.put(doc)
    }

    assert_numdocs(200)

    vespa.storage["storage"].get_master_fleet_controller().set_node_state("storage", 2, "s:u");

    vespa.storage["storage"].storage["2"].wait_for_current_node_state('u')
    vespa.storage["storage"].wait_until_ready
    sleep(60)

    assert_numdocs(200)

    vespa.storage["storage"].storage.each_value { |node|
      assert(get_last_numdocs(node) > 50)
    }
  end

  def assert_numdocs(numDocs)
    n = -1
    until n == numDocs
      sleep 5

      n = 0
      within_total = 0
      vespa.storage["storage"].storage.each_value { |node|
        lastval = get_last_numdocs(node)
        puts "Docs #{lastval}"
        n += lastval
      }
      puts "num docs " + n.to_s
    end

    assert_equal(numDocs, n)
  end


  def teardown
    stop
  end
end

