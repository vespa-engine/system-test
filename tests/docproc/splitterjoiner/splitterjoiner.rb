# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'docproc_test'

class SplitterJoiner < DocprocTest

  def setup
    set_owner("havardpe")
    add_bundle(selfdir+"DocInDocProcessor.java")
    add_bundle(selfdir+"OuterDocProcessor.java")
    deploy(selfdir+"app")
    start
  end

  def test_splitterjoiner
    feedfile(selfdir+"test_docindoc.xml", :route => "container/container.0/chain.default")

    #assert that outerdoc got split
    nummatches = assert_log_matches("docindoc1 in default GOT DOCINDOC: id:inner:docindoc::this:is:inner:doc:a")
    nummatches = assert_log_matches("docindoc1 in default GOT DOCINDOC: id:inner:docindoc::this:is:inner:doc:b")
    nummatches = assert_log_matches("docindoc1 in default GOT DOCINDOC: id:inner:docindoc::this:is:inner:doc:c")

    nummatches = assert_log_matches("docindoc2 in default GOT OUTERDOC: id:outer:outerdoc::this:is:outer:doc")
    nummatches = assert_log_matches("docindoc2 in default GOT INNERDOC: document 'id:inner:docindoc::this:is:inner:doc:a' of type 'docindoc'")
    nummatches = assert_log_matches("docindoc2 in default GOT INNERDOC: document 'id:inner:docindoc::this:is:inner:doc:b' of type 'docindoc'")
    nummatches = assert_log_matches("docindoc2 in default GOT INNERDOC: document 'id:inner:docindoc::this:is:inner:doc:c' of type 'docindoc'")

    #we should have 1 docs in vds here:
    #visitoutput = vespa.storage["storage"].storage["0"].remove("vespa-visit -i")
    #assert_equal(0, $?)
    #numdocs = vespa.storage["storage"].storage["0"].remove("vespa-visit -i | wc -l")
    #assert_equal(0, $?)
    #assert_equal(1, numdocs.to_i)

    #doc1 = vespa.document_api_v1.get("id:outer:outerdoc::this:is:outer:doc")
    #assert(!doc1.nil?)
  end

  def teardown
    stop
  end
end

