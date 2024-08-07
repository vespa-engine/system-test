# Copyright Vespa.ai. All rights reserved.

require 'vds_test'
require 'json'

class ClusterControllerStandaloneZooKeeperTest < VdsTest

  def initialize(*args)
    super(*args)
    @num_hosts = 4
  end

  def setup
    @docnr = 0
    @valgrind=false
    set_owner("vekterli")
  end

    # The bucket count test currently have to wait for 5 minute shapshot to
    # be taken
  def timeout_seconds
    return 600
  end

  def feed_docs(doccount = 10)
    puts "\nFEEDING DOCS\n"
    doccount.times { |i|
      nr = @docnr
      @docnr += 1
      doc = Document.new("music", "id:storage_test:music::" + nr.to_s).
        add_field("title", "title")
      vespa.document_api_v1.put(doc)
    }
  end

  def test_standalone_singlenode
    # Feed 10 docs.. Verify that both distributors
     #
    app = default_app.provider("PROTON").num_hosts(2)
    app.admin(Admin.new.clustercontrollers(true).
                        clustercontroller("node2"))
    app.redundancy(1).num_nodes(1)
    deploy_app(app)
    start
    feed_docs
  end

  def test_standalone_multinode
    # Feed 10 docs.. Verify that both distributors
     #
    app = default_app.provider("PROTON").num_hosts(4)
    app.admin(Admin.new.clustercontrollers(true).
                        clustercontroller("node2").
                        clustercontroller("node3").
                        clustercontroller("node4"))
    app.redundancy(1).num_nodes(1)
    deploy_app(app)
    start
    feed_docs
  end

  def teardown
    stop
  end
end

