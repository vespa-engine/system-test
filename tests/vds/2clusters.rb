# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class MultipleClusters < VdsTest

  def timeout_seconds
    return 800
  end

  def setup
    @valgrind=false
    set_owner("vekterli")
  end

  def teardown
    stop
  end

  def feed_docs(start, stop, cluster)
    # Feed documents
    params = {
      :route => cluster
    }
    (stop-start).times{|i|
      id=start+i
      doc = Document.new("music", "id:storage_test:music:n=#{id}:0")
      vespa.document_api_v1.put(doc, params)
    }
  end

  def get_docs(start, stop, cluster)
    params = {
      :route => cluster
    }
    # Get documents from vds
    (stop-start).times{|i|
      id=start+i
      doc = Document.new("music", "id:storage_test:music:n=#{id}:0")
      doc2 = vespa.document_api_v1.get("id:storage_test:music:n=#{id}:0", params)
      assert_equal(doc, doc2)
    }
  end

  def visit_docs(start, stop, cluster)
    # Visit documents from vds
    output = vespa.storage[cluster].storage["0"].execute("vespa-visit --xmloutput -c #{cluster}|| true")
    (stop-start).times{|i|
      id=start+i
      assert_match(/id:storage_test:music:n=#{id}/, output)
    }
  end

  def remove_docs(start, stop, cluster)
    # Remove documents from vds
    params = {
      :route => cluster
    }
    (stop-start).times{|i|
      id=start+i
      vespa.document_api_v1.remove("id:storage_test:music:n=#{id}:0", params)
      assert_equal(nil, vespa.document_api_v1.get("id:storage_test:music:n=#{id}:0", params))
    }
  end

  def test_vds_with_two_clusters
    deploy(selfdir + "setup-1x1-2clusters")
    start

    feed_docs(0, 99, "vds1")
    feed_docs(100, 199, "vds2")

    get_docs(0, 99, "vds1")
    get_docs(100, 199, "vds2")

    visit_docs(0, 99, "vds1")
    visit_docs(100, 199, "vds2")

    remove_docs(0, 99, "vds1")
    remove_docs(100, 199, "vds2")
  end

end
